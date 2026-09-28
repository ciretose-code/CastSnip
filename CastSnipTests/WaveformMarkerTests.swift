import Testing
import Foundation
@testable import CastSnip

struct WaveformMarkerTests {

    @Test func markersIncludeChapterAtZero() {
        let chapters = [
            Chapter(title: "Intro", startTime: 0, endTime: 4000),
            Chapter(title: "Interview", startTime: 4000, endTime: 10_000)
        ]

        let markers = WaveformView.makeMarkers(from: chapters)

        #expect(markers.count == 2)
        #expect(markers.contains { $0.time == 0 && $0.label == "Intro" })
    }

    @Test func markersUseChapterTitlesNotIndexes() {
        let chapters = [
            Chapter(title: "Sponsor", startTime: 1500, endTime: 3000)
        ]

        let markers = WaveformView.makeMarkers(from: chapters)

        #expect(markers.count == 1)
        #expect(markers[0].label == "Sponsor")
        #expect(markers[0].time == 1.5)
        #expect(markers[0].id == chapters[0].id)
    }

    @Test func markersSortByStartTime() {
        let late = Chapter(title: "End", startTime: 9000, endTime: 10_000)
        let early = Chapter(title: "Start", startTime: 0, endTime: 2000)

        let markers = WaveformView.makeMarkers(from: [late, early])

        #expect(markers.map(\.label) == ["Start", "End"])
    }

    @Test func emptyTitleFallsBackToChapter() {
        let chapters = [Chapter(title: "   ", startTime: 0, endTime: 1000)]
        let markers = WaveformView.makeMarkers(from: chapters)
        #expect(markers[0].label == "Chapter")
    }

    @Test func onlyTheFirstMarkerIsLocked() {
        let chapters = [
            Chapter(title: "Intro", startTime: 0, endTime: 4000),
            Chapter(title: "Interview", startTime: 4000, endTime: 10_000)
        ]

        let markers = WaveformView.makeMarkers(from: chapters)

        #expect(markers.map(\.isLocked) == [true, false])
    }
}
