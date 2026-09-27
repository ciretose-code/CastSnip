import Testing
import Foundation
import AVFoundation
@testable import CastSnip

struct SilenceSettingsStoreTests {

    @Test func missingPreferenceUsesForecastStyleDefaults() {
        let suite = "CastSnip.SilenceSettingsStoreTests.default.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = SilenceSettingsStore(defaults: defaults)

        #expect(store.durationSeconds == SilenceDetector.defaultDurationSeconds)
        #expect(store.thresholdDb == SilenceDetector.defaultThresholdDb)
        #expect(store.durationSeconds == 3)
        #expect(store.thresholdDb == -40)
    }

    @Test func changingDurationAndThresholdPersistsAcrossLoads() {
        let suite = "CastSnip.SilenceSettingsStoreTests.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let first = SilenceSettingsStore(defaults: defaults)
        first.durationSeconds = 1.5
        first.thresholdDb = -25

        let second = SilenceSettingsStore(defaults: defaults)
        #expect(second.durationSeconds == 1.5)
        #expect(second.thresholdDb == -25)

        second.durationSeconds = 5
        second.thresholdDb = -50
        let third = SilenceSettingsStore(defaults: defaults)
        #expect(third.durationSeconds == 5)
        #expect(third.thresholdDb == -50)
    }
}

struct SilenceWarningSettingsTests {

    @Test func detectorRangesUseStoreThresholdAndDuration() {
        let windows = [
            SilenceDetector.Window(start: 0, end: 2, peakDb: -30),
        ]
        let store = makeStore()

        store.durationSeconds = 0.5
        store.thresholdDb = -20
        #expect(SilenceDetector.ranges(in: windows, settings: store) == [
            SilenceDetector.Range(start: 0, end: 2),
        ])

        store.thresholdDb = -40
        #expect(SilenceDetector.ranges(in: windows, settings: store).isEmpty)

        store.thresholdDb = -20
        store.durationSeconds = 3
        #expect(SilenceDetector.ranges(in: windows, settings: store).isEmpty)
    }

    @Test func silenceRangesAndWarningUseStoreSettings() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-silence-settings-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try ProductionAudioFixtures.writeWAV(to: url, duration: 1.2) { index, _ in
            index < 44_100 ? 0 : 0.4
        }

        let audio = AudioFile()
        audio.podcast.file = try AVAudioFile(forReading: url)
        let store = makeStore()

        store.durationSeconds = 0.6
        store.thresholdDb = -40
        let found = audio.silenceRanges(settings: store)
        #expect(found.count == 1)
        #expect(found[0].duration >= 0.6)
        #expect(SilenceDetector.warningMessage(for: audio, settings: store) != nil)

        store.durationSeconds = 3
        #expect(audio.silenceRanges(settings: store).isEmpty)
        #expect(SilenceDetector.warningMessage(for: audio, settings: store) == nil)
    }

    @Test func settingsCopyDescribesDurationAndThreshold() {
        #expect(SilenceSettingsView.durationLabel == "Minimum silence duration")
        #expect(SilenceSettingsView.thresholdLabel == "Silence threshold")
        #expect(SilenceSettingsView.durationUnit == "seconds")
        #expect(SilenceSettingsView.thresholdUnit == "dBFS")
    }
}

private func makeStore() -> SilenceSettingsStore {
    let suite = "CastSnip.SilenceSettingsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return SilenceSettingsStore(defaults: defaults)
}
