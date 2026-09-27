//
//  AudioPlayerManager.swift
//  CastSnip
//
//  Lightweight playback controller used by the waveform viewport + transport controls.
//

import Foundation
import AVFoundation
import OSLog

final class AudioPlayerManager: ObservableObject {
    private let logger = Logger(subsystem: "com.castsnip", category: "AudioPlayer")

    private var player: AVAudioPlayer?
    private var timer: Timer?

    var url: URL?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var loadError: String?

    func load(url: URL?) {
        stopTimer()
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
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = true
        }
        startTimer()
    }

    func pause() {
        player?.pause()
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
        }
        stopTimer()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(time, duration))
        player.currentTime = clamped
        DispatchQueue.main.async { [weak self] in
            self?.currentTime = clamped
        }
    }

    func jumpForward(_ seconds: TimeInterval = 15) {
        seek(to: currentTime + seconds)
    }

    func jumpBackward(_ seconds: TimeInterval = 15) {
        seek(to: currentTime - seconds)
    }

    // MARK: - Timer

    private func startTimer() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer?.tolerance = 1.0 / 60.0
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Tests call this after a real `AVAudioPlayer` finishes because `Timer` does not fire on the Swift Testing run loop.
    func tick() {
        guard let player else { return }
        if !player.isPlaying, player.duration > 0 {
            let atEnd = player.currentTime >= player.duration - 0.05
            // AVAudioPlayer resets `currentTime` to 0 when the file ends.
            let finishedAndWrapped = isPlaying && player.currentTime < 0.05
            if atEnd || finishedAndWrapped {
                stopTimer()
                setPublished(isPlaying: false, currentTime: player.duration, duration: player.duration)
                return
            }
        }
        setPublished(isPlaying: player.isPlaying, currentTime: player.currentTime, duration: player.duration)
    }

    private func setPublished(isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPlaying = isPlaying
            self.currentTime = currentTime
            self.duration = duration
        }
    }

    deinit {
        stopTimer()
    }
}