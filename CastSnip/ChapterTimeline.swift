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

    /// The chapter whose range contains `millis`, or the first chapter when `millis` precedes them all.
    static func chapter(at millis: UInt32, in chapters: [Chapter]) -> Chapter? {
        let sorted = chapters.sorted()
        return sorted.last(where: { $0.startTime <= millis }) ?? sorted.first
    }

    /// The first chapter anchors the timeline, so its start can't be moved.
    static func isStartLocked(_ chapter: Chapter, in chapters: [Chapter]) -> Bool {
        chapters.sorted().first?.id == chapter.id
    }

    /// Moves a chapter's start, keeping the timeline contiguous: the previous chapter ends where this one starts.
    /// The new start is clamped so every chapter stays at least `minimumGap` long. The first chapter is locked.
    @discardableResult
    static func moveStart(
        of chapter: Chapter,
        to millis: UInt32,
        in chapters: [Chapter],
        durationMillis: UInt32
    ) -> UInt32 {
        let sorted = chapters.sorted()
        guard let index = sorted.firstIndex(where: { $0.id == chapter.id }), index > 0 else { return chapter.startTime }
        let previous = sorted[index - 1]
        let next = index + 1 < sorted.count ? sorted[index + 1] : nil

        let lower = previous.startTime + minimumGap
        let upperBound = next?.startTime ?? durationMillis
        let upper = upperBound > minimumGap ? upperBound - minimumGap : 0
        let clamped = lower <= upper ? min(max(millis, lower), upper) : chapter.startTime

        chapter.startTime = clamped
        previous.endTime = clamped
        return clamped
    }

    /// Removes a chapter and closes the gap it leaves behind.
    static func removeChapter(_ chapter: Chapter, from chapters: inout [Chapter]) {
        let sorted = chapters.sorted()
        guard let index = sorted.firstIndex(where: { $0.id == chapter.id }) else { return }
        if index > 0 {
            sorted[index - 1].endTime = chapter.endTime
        } else if sorted.count > 1 {
            sorted[1].startTime = chapter.startTime
        }
        chapters.removeAll { $0.id == chapter.id }
    }

    /// Ensures the timeline starts at 0:00 with an "Intro" chapter when none does.
    /// Existing chapters stay after it. Returns `true` when an Intro was inserted.
    @discardableResult
    static func ensureLeadingIntro(
        into chapters: inout [Chapter],
        durationMillis: UInt32
    ) -> Bool {
        guard durationMillis > 0 else { return false }
        if chapters.contains(where: { $0.startTime == 0 }) {
            return false
        }

        let endTime = chapters.sorted().first?.startTime ?? durationMillis
        let intro = Chapter(
            title: "Intro",
            url: "",
            startTime: 0,
            endTime: endTime,
            podcastDuration: durationMillis
        )
        chapters.insert(intro, at: 0)
        return true
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
