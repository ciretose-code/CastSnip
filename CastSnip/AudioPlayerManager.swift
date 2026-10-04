//
//  AudioPlayerManager.swift
//  CastSnip
//
//  Lightweight playback controller used by the waveform viewport + transport controls.
//

import Foundation
import AVFoundation
import AppKit
import QuartzCore
import OSLog

final class AudioPlayerManager: ObservableObject {
    private let logger = Logger(subsystem: "com.castsnip", category: "AudioPlayer")

    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private let displayLinkTarget = DisplayLinkTarget()
    private var fallbackTimer: Timer?
    /// True while a display clock is expected to drive `tick()`. Stale
    /// display-link callbacks already queued must not overwrite an end-of-track
    /// pin after the clock has been stopped.
    private var isDisplayClockRunning = false

    var url: URL?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var loadError: String?

    func load(url: URL?) {
        stopDisplayClock()
        player = nil
        loadError = nil
        setPublished(isPlaying: false, currentTime: 0, duration: 0)
        self.url = url

        guard let url else { return }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            player = p
            setPublished(isPlaying: p.isPlaying, currentTime: p.currentTime, duration: p.duration)
        } catch {
            logger.error("Failed to create AVAudioPlayer: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.loadError = "Could not play this file. \(error.localizedDescription)"
            }
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard let player else { return }
        player.play()
        setPublished(isPlaying: true, currentTime: player.currentTime, duration: player.duration)
        startDisplayClock()
    }

    func pause() {
        player?.pause()
        setPublished(isPlaying: false, currentTime: player?.currentTime ?? currentTime, duration: duration)
        stopDisplayClock()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(time, duration))
        player.currentTime = clamped
        setPublished(isPlaying: isPlaying, currentTime: clamped, duration: duration)
    }

    func jumpForward(_ seconds: TimeInterval = 15) {
        seek(to: currentTime + seconds)
    }

    func jumpBackward(_ seconds: TimeInterval = 15) {
        seek(to: currentTime - seconds)
    }

    // MARK: - Display-synced clock

    private func startDisplayClock() {
        guard displayLink == nil, fallbackTimer == nil else { return }
        isDisplayClockRunning = true

        displayLinkTarget.handler = { [weak self] in
            self?.tick()
        }

        // NSScreen.displayLink is the macOS 15+ replacement for CVDisplayLink.
        if let screen = NSScreen.main {
            let link = screen.displayLink(
                target: displayLinkTarget,
                selector: #selector(DisplayLinkTarget.fire(_:))
            )
            link.add(to: .main, forMode: .common)
            displayLink = link
            return
        }

        // Headless / no active display: stay near 60 Hz on the common run-loop modes.
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 1.0 / 120.0
        RunLoop.main.add(timer, forMode: .common)
        fallbackTimer = timer
    }

    private func stopDisplayClock() {
        isDisplayClockRunning = false
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget.handler = nil

        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    /// Tests call this after a real `AVAudioPlayer` finishes because display clocks do not fire on the Swift Testing run loop.
    func tick() {
        guard let player else { return }
        if !player.isPlaying, player.duration > 0 {
            let atEnd = player.currentTime >= player.duration - 0.05
            // AVAudioPlayer resets `currentTime` to 0 when the file ends.
            let finishedAndWrapped = isPlaying && player.currentTime < 0.05
            if atEnd || finishedAndWrapped {
                stopDisplayClock()
                setPublished(isPlaying: false, currentTime: player.duration, duration: player.duration)
                return
            }
        }
        // Ignore stale display-link frames after stop so they cannot clear a duration pin.
        guard isDisplayClockRunning else { return }
        setPublished(isPlaying: player.isPlaying, currentTime: player.currentTime, duration: player.duration)
    }

    private func setPublished(isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval) {
        let apply = { [weak self] in
            guard let self else { return }
            self.isPlaying = isPlaying
            self.currentTime = currentTime
            self.duration = duration
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    deinit {
        stopDisplayClock()
    }
}

/// `CADisplayLink` requires an NSObject target; keep that detail out of the player API.
private final class DisplayLinkTarget: NSObject {
    var handler: (() -> Void)?

    @objc func fire(_ link: CADisplayLink) {
        handler?()
    }
}
