//
//  ChapterTimeline.swift
//  CastSnip
//

import Foundation

enum ChapterTimeline {
    private static let minimumGap: UInt32 = 1000

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
