import Testing
import Foundation
@testable import CastSnip

struct RecentFilesStoreTests {

    @Test func rememberPutsNewestFirstAndDropsDuplicates() {
        let suite = "CastSnip.RecentFilesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = RecentFilesStore(defaults: defaults)

        store.remember(URL(fileURLWithPath: "/tmp/a.mp3"))
        store.remember(URL(fileURLWithPath: "/tmp/b.mp3"))
        store.remember(URL(fileURLWithPath: "/tmp/a.mp3"))

        #expect(store.paths() == ["/tmp/a.mp3", "/tmp/b.mp3"])
    }

    @Test func rememberCapsTheListAtTen() {
        let suite = "CastSnip.RecentFilesStoreTests.cap.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = RecentFilesStore(defaults: defaults)

        for index in 1...12 {
            store.remember(URL(fileURLWithPath: "/tmp/ep\(index).mp3"))
        }

        #expect(store.paths().count == 10)
        #expect(store.paths().first == "/tmp/ep12.mp3")
        #expect(!store.paths().contains("/tmp/ep1.mp3"))
        #expect(!store.paths().contains("/tmp/ep2.mp3"))
    }

    @Test func rememberSkipsBundledSampleAudio() {
        let suite = "CastSnip.RecentFilesStoreTests.bundle.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = RecentFilesStore(defaults: defaults)

        store.remember(URL(fileURLWithPath: "/Apps/CastSnip.app/Contents/Resources/intro.mp3"))
        store.remember(URL(fileURLWithPath: "/tmp/episode.mp3"))

        #expect(store.paths() == ["/tmp/episode.mp3"])
    }

    @Test func clearRemovesEveryRecentPath() {
        let suite = "CastSnip.RecentFilesStoreTests.clear.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = RecentFilesStore(defaults: defaults)

        store.remember(URL(fileURLWithPath: "/tmp/episode.mp3"))
        store.clear()

        #expect(store.paths().isEmpty)
    }
}

struct ChapterNavigationTests {

    @Test func nextSelectsTheFollowingChapterByStartTime() {
        let intro = Chapter(title: "Intro", startTime: 0, endTime: 4000)
        let ads = Chapter(title: "Ads", startTime: 4000, endTime: 8000)
        let talk = Chapter(title: "Talk", startTime: 8000, endTime: 12_000)

        #expect(ChapterTimeline.neighbor(of: intro, in: [talk, ads, intro], going: .next) === ads)
        #expect(ChapterTimeline.neighbor(of: ads, in: [talk, ads, intro], going: .next) === talk)
        #expect(ChapterTimeline.neighbor(of: talk, in: [talk, ads, intro], going: .next) == nil)
    }

    @Test func previousSelectsTheEarlierChapter() {
        let intro = Chapter(title: "Intro", startTime: 0, endTime: 4000)
        let ads = Chapter(title: "Ads", startTime: 4000, endTime: 8000)

        #expect(ChapterTimeline.neighbor(of: ads, in: [intro, ads], going: .previous) === intro)
        #expect(ChapterTimeline.neighbor(of: intro, in: [intro, ads], going: .previous) == nil)
    }

    @Test func missingSelectionPicksTheEndTowardTheDirection() {
        let intro = Chapter(title: "Intro", startTime: 0, endTime: 4000)
        let ads = Chapter(title: "Ads", startTime: 4000, endTime: 8000)

        #expect(ChapterTimeline.neighbor(of: nil, in: [intro, ads], going: .next) === intro)
        #expect(ChapterTimeline.neighbor(of: nil, in: [intro, ads], going: .previous) === ads)
        #expect(ChapterTimeline.neighbor(of: nil, in: [], going: .next) == nil)
    }
}

struct CloseDocumentTests {

    @Test func closeClearsPodcastAndDirtyState() {
        let audio = AudioFile()
        audio.podcast.title = "Edited Show"
        audio.markAsModified()

        audio.closeDocument()

        #expect(audio.podcast.title.isEmpty)
        #expect(audio.podcast.chapters.isEmpty)
        #expect(audio.selectedChapter == nil)
        #expect(audio.hasUnsavedChanges == false)
        #expect(audio.errorMessage == nil)
    }
}

struct AutofillMemoryCopyTests {

    @Test func helpMenuBrowseTitleDoesNotWipeEverything() {
        #expect(AutofillMemoryCopy.browseMenu.localizedCaseInsensitiveContains("browse"))
        #expect(!AutofillMemoryCopy.browseMenu.localizedCaseInsensitiveContains("clear"))
        #expect(AutofillMemoryCopy.windowTitle.localizedCaseInsensitiveContains("autofill"))
        #expect(AutofillMemoryCopy.showsSection.localizedCaseInsensitiveContains("show"))
        #expect(AutofillMemoryCopy.chaptersSection.localizedCaseInsensitiveContains("chapter"))
        #expect(AutofillMemoryCopy.delete.localizedCaseInsensitiveContains("delete"))
        #expect(AutofillMemoryCopy.clearAll.localizedCaseInsensitiveContains("clear"))
    }
}

struct KeyboardShortcutsHelpTests {

    @Test func helpTextDocumentsFileAndChapterShortcuts() {
        let text = KeyboardShortcutsHelp.text
        #expect(text.contains("⌘O"))
        #expect(text.contains("⌘S"))
        #expect(text.contains("⌘⇧S"))
        #expect(text.contains("⌘W"))
        #expect(text.contains("Space"))
        #expect(text.contains("⌘N"))
        #expect(text.contains("⌘["))
        #expect(text.contains("⌘]"))
        #expect(text.contains("⌘T"))
        #expect(text.contains("⌘0"))
        #expect(text.contains("⌥⌘I"))
        #expect(text.contains("Open Recent"))
        #expect(text.contains("Include ID3 tags"))
    }
}

struct ID3TaggingStoreTests {

    @Test func missingPreferenceDefaultsToIncludingTags() {
        let suite = "CastSnip.ID3TaggingStoreTests.default.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = ID3TaggingStore(defaults: defaults)
        #expect(store.includeTags)
    }

    @Test func togglingPersistsAcrossLoads() {
        let suite = "CastSnip.ID3TaggingStoreTests.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let first = ID3TaggingStore(defaults: defaults)
        first.includeTags = false
        let second = ID3TaggingStore(defaults: defaults)
        #expect(!second.includeTags)

        second.includeTags = true
        let third = ID3TaggingStore(defaults: defaults)
        #expect(third.includeTags)
    }
}

struct EncodeBitrateTests {

    @Test func offersStandardPodcastRates() {
        #expect(EncodeBitrate.allCases.map(\.rawValue) == [64, 96, 128, 192])
        #expect(EncodeBitrate.default == .kbps192)
    }

    @Test func resolvedFallsBackToDefaultForUnknownRates() {
        #expect(EncodeBitrate.resolved(128) == .kbps128)
        #expect(EncodeBitrate.resolved(999) == .default)
    }

    @Test func missingPreferenceDefaultsTo192() {
        let suite = "CastSnip.EncodeBitrateStoreTests.default.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = EncodeBitrateStore(defaults: defaults)
        #expect(store.bitrate == .kbps192)
    }

    @Test func selectionPersistsAcrossLoads() {
        let suite = "CastSnip.EncodeBitrateStoreTests.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let first = EncodeBitrateStore(defaults: defaults)
        first.bitrate = .kbps64
        let second = EncodeBitrateStore(defaults: defaults)
        #expect(second.bitrate == .kbps64)

        second.bitrate = .kbps128
        let third = EncodeBitrateStore(defaults: defaults)
        #expect(third.bitrate == .kbps128)
    }
}
