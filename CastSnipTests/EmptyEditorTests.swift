import Testing
import Foundation
import SwiftUI
@testable import CastSnip

struct EmptyEditorCopyTests {

    @Test func emptyWindowExplainsDropAndOpen() {
        #expect(EmptyEditorCopy.title.localizedCaseInsensitiveContains("audio"))
        #expect(EmptyEditorCopy.detail.localizedCaseInsensitiveContains("drop"))
        #expect(EmptyEditorCopy.detail.localizedCaseInsensitiveContains("open"))
    }

    @Test func chapterListEmptyStateExplainsAddAndMarkers() {
        #expect(EmptyEditorCopy.chapters.localizedCaseInsensitiveContains("add"))
        #expect(EmptyEditorCopy.chapters.localizedCaseInsensitiveContains("marker"))
    }
}

struct SampleEpisodeTests {

    @Test func sampleEpisodeIsInTheAppBundle() {
        let url = SampleEpisode.url(in: Bundle(for: AudioFile.self))
        #expect(url != nil)
        #expect(url?.lastPathComponent == "intro.mp3")
    }

    @Test func bundledIntroIsTreatedAsASampleNotAUserDocument() {
        let url = URL(fileURLWithPath: "/Applications/CastSnip.app/Contents/Resources/intro.mp3")
        #expect(SampleEpisode.isSample(url))
        #expect(!SampleEpisode.isSample(URL(fileURLWithPath: "/Users/eric/episode.mp3")))
    }
}

struct OptionalAlertTests {

    @Test func dismissingTheAlertClearsTheMessage() {
        var message: String? = "Could not load file"
        let presented = OptionalAlert.isPresented(
            Binding(get: { message }, set: { message = $0 })
        )

        #expect(presented.wrappedValue == true)
        presented.wrappedValue = false
        #expect(message == nil)
        #expect(presented.wrappedValue == false)
    }
}

struct EditorAccessibilityTests {

    @Test func coverAndTransportHaveVoiceOverNames() {
        #expect(EditorAccessibility.coverArt == "Cover art")
        #expect(EditorAccessibility.back10.contains("10"))
        #expect(EditorAccessibility.forward10.contains("10"))
        #expect(EditorAccessibility.viewport.localizedCaseInsensitiveContains("zoom"))
    }

    @Test func chapterRowNamesUntitledWhenTitleIsEmpty() {
        let label = EditorAccessibility.chapterRow(title: "", start: "0:00", end: "1:00")
        #expect(label.localizedCaseInsensitiveContains("untitled"))
        #expect(label.contains("0:00"))
        #expect(label.contains("1:00"))
    }
}
