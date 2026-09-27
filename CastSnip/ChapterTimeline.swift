//
//  ChapterTimeline.swift
//  CastSnip
//

import Foundation

enum ChapterTimeline {
    enum NeighborDirection {
        case next
        case previous
    }

    private static let minimumGap: UInt32 = 1000

    static func neighbor(
        of selected: Chapter?,
        in chapters: [Chapter],
        going direction: NeighborDirection
    ) -> Chapter? {
        let sorted = chapters.sorted()
        guard !sorted.isEmpty else { return nil }
        guard let selected, let index = sorted.firstIndex(where: { $0.id == selected.id }) else {
            return direction == .next ? sorted.first : sorted.last
        }
        switch direction {
        case .next:
            let next = index + 1
            return next < sorted.count ? sorted[next] : nil
        case .previous:
            return index > 0 ? sorted[index - 1] : nil
        }
    }

    @discardableResult
    static func insertChapter(
        into chapters: inout [Chapter],
        atPlayhead playheadMillis: UInt32,
        durationMillis: UInt32
    ) -> Chapter {
        let duration = durationMillis
        let playhead = min(playheadMillis, duration)

        if chapters.isEmpty {
            let chapter = Chapter(
                title: "New Chapter",
                url: "",
                startTime: 0,
                endTime: duration,
                podcastDuration: duration
            )
            chapters.append(chapter)
            return chapter
        }

        let sorted = chapters.sorted()

        if let containing = sorted.last(where: { $0.startTime <= playhead }) {
            let next = sorted.first(where: { $0.startTime > containing.startTime })
            let rangeEnd = next?.startTime ?? duration
            var start = playhead
            if start <= containing.startTime {
                start = min(containing.startTime + minimumGap, rangeEnd)
            }
            if start >= rangeEnd, rangeEnd > containing.startTime {
                start = containing.startTime + ((rangeEnd - containing.startTime) / 2)
            }

            containing.endTime = start
            let chapter = Chapter(
                title: "New Chapter",
                url: "",
                startTime: start,
                endTime: rangeEnd,
                podcastDuration: duration
            )
            if let index = chapters.firstIndex(where: { $0.id == containing.id }) {
                chapters.insert(chapter, at: index + 1)
            } else {
                chapters.append(chapter)
            }
            return chapter
        }

        let first = sorted[0]
        let chapter = Chapter(
            title: "New Chapter",
            url: "",
            startTime: 0,
            endTime: first.startTime,
            podcastDuration: duration
        )
        chapters.insert(chapter, at: 0)
        return chapter
    }
}
