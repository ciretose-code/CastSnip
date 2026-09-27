import Testing
import Foundation
import AppKit
@testable import CastSnip

struct ShowAutofillTests {

    @Test func parsesPrefixAndEpisodeFromATPStyleFilenames() {
        let store = isolatedStore()

        let mp3 = store.suggestion(forFilename: "atp100.mp3")
        #expect(mp3.episode == "100")
        #expect(mp3.title == nil)
        #expect(mp3.artwork == nil)

        let wav = store.suggestion(forFilename: "atp100.wav")
        #expect(wav.episode == "100")
    }

    @Test func parsesHyphenatedShowFilename() {
        let store = isolatedStore()
        let suggestion = store.suggestion(forFilename: "show-12.mp3")
        #expect(suggestion.episode == "12")
        #expect(suggestion.title == nil)
    }

    @Test func parsesMultiHyphenShowFilename() {
        let parsed = ShowAutofillStore.parse("the-talk-show-12.mp3")
        #expect(parsed?.prefix == "the-talk-show")
        #expect(parsed?.episode == "12")
    }

    @Test func filenameWithoutTrailingNumberHasNoEpisode() {
        let store = isolatedStore()
        let suggestion = store.suggestion(forFilename: "episode.mp3")
        #expect(suggestion.episode == nil)
        #expect(suggestion.title == nil)
    }

    @Test func ignoresBundledSampleIntro() {
        let store = isolatedStore()
        store.rememberShow(prefix: "intro", title: "Should Not Apply", artwork: swatch(.blue))

        let bundled = store.suggestion(
            forFilename: "/Apps/CastSnip.app/Contents/Resources/intro.mp3"
        )
        #expect(bundled.title == nil)
        #expect(bundled.episode == nil)
        #expect(bundled.artwork == nil)
        #expect(SampleEpisode.isSample(URL(fileURLWithPath: "/Apps/CastSnip.app/Contents/Resources/intro.mp3")))
    }

    @Test func remembersShowTitleAndArtworkForPrefix() {
        let store = isolatedStore()
        let art = swatch(.red)
        store.rememberShow(prefix: "atp", title: "Accidental Tech Podcast", artwork: art)

        let suggestion = store.suggestion(forFilename: "atp100.mp3")
        #expect(suggestion.title == "Accidental Tech Podcast")
        #expect(suggestion.episode == "100")
        #expect(suggestion.artwork != nil)
        #expect(suggestion.artwork?.tiffRepresentation != nil)
    }

    @Test func showMemoryIsLookedUpByLowercasedPrefix() {
        let store = isolatedStore()
        store.rememberShow(prefix: "ATP", title: "Accidental Tech Podcast", artwork: nil)

        let suggestion = store.suggestion(forFilename: "/tmp/atp101.wav")
        #expect(suggestion.title == "Accidental Tech Podcast")
        #expect(suggestion.episode == "101")
    }

    @Test func remembersChapterURLAndImageByNormalizedTitle() {
        let store = isolatedStore()
        let art = swatch(.green)
        store.rememberChapter(title: "  Squarespace  ", url: "https://squarespace.com", image: art)

        let suggestion = store.suggestion(forChapterTitle: "squarespace")
        #expect(suggestion.url == "https://squarespace.com")
        #expect(suggestion.image != nil)
    }

    @Test func applyToPodcastFillsOnlyEmptyFields() {
        let store = isolatedStore()
        store.rememberShow(prefix: "atp", title: "Accidental Tech Podcast", artwork: swatch(.orange))

        let empty = Podcast()
        store.applyToPodcastIfEmpty(empty, filename: "atp100.mp3")
        #expect(empty.title == "Accidental Tech Podcast")
        #expect(empty.episode == "100")
        #expect(empty.logo != nil)

        let typed = Podcast()
        typed.title = "User Title"
        typed.episode = "99"
        let existingLogo = swatch(.black)
        typed.logo = existingLogo
        store.applyToPodcastIfEmpty(typed, filename: "atp100.mp3")
        #expect(typed.title == "User Title")
        #expect(typed.episode == "99")
        #expect(typed.logo === existingLogo)
    }

    @Test func applyToPodcastSkipsBundledSample() {
        let store = isolatedStore()
        store.rememberShow(prefix: "intro", title: "Sample Show", artwork: swatch(.purple))

        let podcast = Podcast()
        store.applyToPodcastIfEmpty(
            podcast,
            filename: "/Apps/CastSnip.app/Contents/Resources/intro.mp3"
        )
        #expect(podcast.title.isEmpty)
        #expect(podcast.episode.isEmpty)
        #expect(podcast.logo == nil)
    }

    @Test func applyToChapterFillsOnlyEmptyURLAndImage() {
        let store = isolatedStore()
        store.rememberChapter(
            title: "Sponsor",
            url: "https://example.com/offer",
            image: swatch(.cyan)
        )

        let empty = Chapter(title: "Sponsor")
        store.applyToChapterIfEmpty(empty)
        #expect(empty.url == "https://example.com/offer")
        #expect(empty.image != nil)

        let typed = Chapter(title: "Sponsor", url: "https://already.example")
        let existing = swatch(.magenta)
        typed.image = existing
        store.applyToChapterIfEmpty(typed)
        #expect(typed.url == "https://already.example")
        #expect(typed.image === existing)
    }

    @Test func memorySurvivesANewStoreOnTheSameDefaults() {
        let suite = "CastSnip.ShowAutofillTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let first = ShowAutofillStore(defaults: defaults)
        first.rememberShow(prefix: "show", title: "The Show", artwork: swatch(.yellow))
        first.rememberChapter(title: "Ad", url: "https://ads.example", image: nil)

        let second = ShowAutofillStore(defaults: defaults)
        let show = second.suggestion(forFilename: "show-12.mp3")
        #expect(show.title == "The Show")
        #expect(show.episode == "12")
        #expect(show.artwork != nil)

        let chapter = second.suggestion(forChapterTitle: "Ad")
        #expect(chapter.url == "https://ads.example")
    }

    @Test func clearWipesShowAndChapterMemory() {
        let store = isolatedStore()
        store.rememberShow(prefix: "atp", title: "Accidental Tech Podcast", artwork: swatch(.red))
        store.rememberChapter(title: "Sponsor", url: "https://example.com", image: swatch(.blue))

        store.clear()

        let show = store.suggestion(forFilename: "atp100.mp3")
        #expect(show.title == nil)
        #expect(show.artwork == nil)
        #expect(show.episode == "100")

        let chapter = store.suggestion(forChapterTitle: "Sponsor")
        #expect(chapter.url == nil)
        #expect(chapter.image == nil)
    }

    private func isolatedStore() -> ShowAutofillStore {
        let suite = "CastSnip.ShowAutofillTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ShowAutofillStore(defaults: defaults)
    }

    private func swatch(_ color: NSColor) -> NSImage {
        let size = NSSize(width: 4, height: 4)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}
