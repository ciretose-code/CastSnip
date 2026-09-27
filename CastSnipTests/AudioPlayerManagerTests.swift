import Testing
import Foundation
import AVFoundation
@testable import CastSnip

struct AudioPlayerManagerTests {

    @Test func loadNilClearsPlaybackStateAndDoesNotPlay() async {
        let player = AudioPlayerManager()
        player.duration = 42
        player.currentTime = 17
        player.loadError = "stale error"
        player.isPlaying = true

        player.load(url: nil)
        await waitForMainQueuePublishedUpdates()

        #expect(player.duration == 0)
        #expect(player.currentTime == 0)
        #expect(player.loadError == nil)
        #expect(player.isPlaying == false)

        player.play()
        await waitForMainQueuePublishedUpdates()
        #expect(player.isPlaying == false)
    }

    @Test func loadMissingFileSetsLoadError() async {
        let player = AudioPlayerManager()
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-missing-\(UUID().uuidString).mp3")

        player.load(url: missing)
        await waitForMainQueuePublishedUpdates()

        #expect(player.loadError != nil)
        #expect(player.loadError?.contains("Could not play") == true)
        #expect(player.isPlaying == false)
    }

    @Test func loadBundledOrSynthesizedAudioSetsDurationAndClearsError() async throws {
        let fixture = try PlayableAudioFixture.make()
        defer { fixture.tearDown() }

        let player = AudioPlayerManager()
        player.loadError = "stale error"
        player.load(url: fixture.url)
        await waitForMainQueuePublishedUpdates()

        #expect(player.duration > 0)
        #expect(player.loadError == nil)
        #expect(player.isPlaying == false)
    }

    @Test func seekClampsBelowZeroAndAboveDuration() async throws {
        let fixture = try PlayableAudioFixture.make()
        defer { fixture.tearDown() }

        let player = AudioPlayerManager()
        player.load(url: fixture.url)
        await waitForMainQueuePublishedUpdates()
        #expect(player.duration > 0)

        player.seek(to: -12)
        await waitForMainQueuePublishedUpdates()
        #expect(player.currentTime == 0)

        player.seek(to: player.duration + 80)
        await waitForMainQueuePublishedUpdates()
        #expect(abs(player.currentTime - player.duration) < 0.001)
    }

    @Test func jumpForwardAndBackwardMoveCurrentTime() async throws {
        let fixture = try PlayableAudioFixture.make()
        defer { fixture.tearDown() }

        let player = AudioPlayerManager()
        player.load(url: fixture.url)
        await waitForMainQueuePublishedUpdates()
        #expect(player.duration > 0)

        let origin = min(1.0, player.duration / 4)
        let delta = min(0.4, origin)

        player.seek(to: origin)
        await waitForMainQueuePublishedUpdates()
        #expect(abs(player.currentTime - origin) < 0.05)

        player.jumpForward(delta)
        await waitForMainQueuePublishedUpdates()
        #expect(abs(player.currentTime - (origin + delta)) < 0.05)

        player.jumpBackward(delta)
        await waitForMainQueuePublishedUpdates()
        #expect(abs(player.currentTime - origin) < 0.05)
    }

    @Test func playWithNoLoadedFileIsANoOp() async {
        let player = AudioPlayerManager()
        #expect(player.isPlaying == false)

        player.play()
        await waitForMainQueuePublishedUpdates()

        #expect(player.isPlaying == false)
        #expect(player.currentTime == 0)
        #expect(player.duration == 0)
    }

    @Test func playPauseAndToggleUpdateIsPlayingAfterSuccessfulLoad() async throws {
        let fixture = try PlayableAudioFixture.make(duration: 0.4)
        defer { fixture.tearDown() }

        let player = AudioPlayerManager()
        player.load(url: fixture.url)
        await waitForMainQueuePublishedUpdates()
        #expect(player.duration > 0)
        #expect(player.isPlaying == false)

        player.play()
        await waitForMainQueuePublishedUpdates()
        #expect(player.isPlaying == true)

        player.pause()
        await waitForMainQueuePublishedUpdates()
        #expect(player.isPlaying == false)

        player.togglePlayPause()
        await waitForMainQueuePublishedUpdates()
        #expect(player.isPlaying == true)

        player.togglePlayPause()
        await waitForMainQueuePublishedUpdates()
        #expect(player.isPlaying == false)
    }

    @Test func endOfTrackStopsPlaybackAndPinsCurrentTimeToDuration() async throws {
        let fixture = try PlayableAudioFixture.make(duration: 0.25)
        defer { fixture.tearDown() }

        let player = AudioPlayerManager()
        player.load(url: fixture.url)
        await waitForMainQueuePublishedUpdates()
        #expect(player.duration > 0)

        player.play()
        await waitForMainQueuePublishedUpdates()
        #expect(player.isPlaying == true)

        try await Task.sleep(for: .milliseconds(400))
        player.tick()
        await waitForMainQueuePublishedUpdates()

        #expect(player.isPlaying == false)
        #expect(abs(player.currentTime - player.duration) < 0.05)
    }
}

/// Waits for work already queued on the main thread (published `currentTime` / `duration` / `loadError`).
private func waitForMainQueuePublishedUpdates() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
            continuation.resume()
        }
    }
    try? await Task.sleep(for: .milliseconds(40))
}

private struct PlayableAudioFixture {
    let url: URL
    let isTemporary: Bool

    func tearDown() {
        guard isTemporary else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func make(duration: TimeInterval = 2) throws -> PlayableAudioFixture {
        if duration == 2 {
            if let bundled = Bundle(for: AudioFile.self).url(forResource: "intro", withExtension: "mp3") {
                return PlayableAudioFixture(url: bundled, isTemporary: false)
            }
            if let main = Bundle.main.url(forResource: "intro", withExtension: "mp3") {
                return PlayableAudioFixture(url: main, isTemporary: false)
            }
            let fromSource = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("CastSnip/Samples/intro.mp3")
            if FileManager.default.fileExists(atPath: fromSource.path) {
                return PlayableAudioFixture(url: fromSource, isTemporary: false)
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-player-\(UUID().uuidString).wav")
        try writePlayableWAV(to: url, duration: duration)
        return PlayableAudioFixture(url: url, isTemporary: true)
    }
}

private func writePlayableWAV(to url: URL, duration: TimeInterval, sampleRate: Double = 44_100) throws {
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    let frameCount = AVAudioFrameCount(duration * sampleRate)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    buffer.frameLength = frameCount
    let channel = buffer.floatChannelData![0]
    for index in 0..<Int(frameCount) {
        channel[index] = Float(sin(2 * Double.pi * 440 * Double(index) / sampleRate)) * 0.25
    }
    try file.write(from: buffer)
}
