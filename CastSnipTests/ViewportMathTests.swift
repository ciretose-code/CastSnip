import XCTest
@testable import CastSnip

final class ViewportMathTests: XCTestCase {
    func testViewportStart_WhenDurationShorterThanViewport_IsZero() {
        XCTAssertEqual(ViewportMath.viewportStart(currentTime: 0, duration: 5, viewportDuration: 20), 0)
        XCTAssertEqual(ViewportMath.viewportStart(currentTime: 3, duration: 5, viewportDuration: 20), 0)
    }

    func testViewportStart_NearBeginning_ClampsToZero() {
        // Centered would be negative, should clamp to 0
        XCTAssertEqual(ViewportMath.viewportStart(currentTime: 1, duration: 60, viewportDuration: 20), 0)
        XCTAssertEqual(ViewportMath.viewportStart(currentTime: 9, duration: 60, viewportDuration: 20), 0)
    }

    func testViewportStart_MidTrack_CentersPlayhead() {
        // With 20s viewport, centeredStart at t=30 should be 20
        XCTAssertEqual(ViewportMath.viewportStart(currentTime: 30, duration: 60, viewportDuration: 20), 20, accuracy: 0.0001)
    }

    func testViewportStart_NearEnd_ClampsToDurationMinusViewport() {
        // duration 60, viewport 20 => max start 40
        XCTAssertEqual(ViewportMath.viewportStart(currentTime: 58, duration: 60, viewportDuration: 20), 40, accuracy: 0.0001)
        XCTAssertEqual(ViewportMath.viewportStart(currentTime: 60, duration: 60, viewportDuration: 20), 40, accuracy: 0.0001)
    }

    func testSeekTime_MapsClickXToViewportTime() throws {
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.seekTime(x: 0, width: 200, viewportStart: 10, viewportDuration: 20, audioDuration: 100)),
            10,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.seekTime(x: 100, width: 200, viewportStart: 10, viewportDuration: 20, audioDuration: 100)),
            20,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.seekTime(x: 200, width: 200, viewportStart: 10, viewportDuration: 20, audioDuration: 100)),
            30,
            accuracy: 0.0001
        )
    }

    func testSeekTime_ClampsClickOutsideCanvas() throws {
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.seekTime(x: -40, width: 200, viewportStart: 10, viewportDuration: 20, audioDuration: 100)),
            10,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.seekTime(x: 260, width: 200, viewportStart: 10, viewportDuration: 20, audioDuration: 100)),
            30,
            accuracy: 0.0001
        )
    }

    func testSeekTime_ClampsToAudioDurationWhenKnown() throws {
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.seekTime(x: 200, width: 200, viewportStart: 90, viewportDuration: 20, audioDuration: 100)),
            100,
            accuracy: 0.0001
        )
    }

    func testSeekTime_ClampsBelowZeroWhenDurationUnknown() throws {
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.seekTime(x: 0, width: 200, viewportStart: -4, viewportDuration: 20, audioDuration: 0)),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.seekTime(x: 0, width: 200, viewportStart: 8, viewportDuration: 20, audioDuration: 0)),
            8,
            accuracy: 0.0001
        )
    }

    func testSeekTime_ReturnsNilWhenWidthOrViewportIsInvalid() {
        XCTAssertNil(ViewportMath.seekTime(x: 10, width: 0, viewportStart: 0, viewportDuration: 20, audioDuration: 100))
        XCTAssertNil(ViewportMath.seekTime(x: 10, width: 200, viewportStart: 0, viewportDuration: 0, audioDuration: 100))
    }

    func testPanDeltaSeconds_ConvertsScrollPointsToTime() throws {
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.panDeltaSeconds(deltaX: 100, width: 200, viewportDuration: 20)),
            -10,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.panDeltaSeconds(deltaX: -50, width: 200, viewportDuration: 20)),
            5,
            accuracy: 0.0001
        )
    }

    func testPanDeltaSeconds_ReturnsNilWhenWidthOrViewportIsInvalid() {
        XCTAssertNil(ViewportMath.panDeltaSeconds(deltaX: 10, width: 0, viewportDuration: 20))
        XCTAssertNil(ViewportMath.panDeltaSeconds(deltaX: 10, width: 200, viewportDuration: 0))
    }

    func testPanDeltaSeconds_UsesVerticalDeltaWhenItDominates() throws {
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.panDeltaSeconds(deltaX: 4, deltaY: 40, width: 200, viewportDuration: 20)),
            -4,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.panDeltaSeconds(deltaX: -80, deltaY: 10, width: 200, viewportDuration: 20)),
            8,
            accuracy: 0.0001
        )
    }

    func testPanDeltaSeconds_ShiftUsesVerticalWheelAsHorizontalPan() throws {
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.panDeltaSeconds(
                deltaX: 100, deltaY: -40, shift: true, width: 200, viewportDuration: 20
            )),
            4,
            accuracy: 0.0001
        )
    }

    func testPanDeltaSeconds_ReturnsNilWhenScrollIsZero() {
        XCTAssertNil(ViewportMath.panDeltaSeconds(deltaX: 0, deltaY: 0, width: 200, viewportDuration: 20))
    }

    func testClampViewportStart_ClampsPanBelowZeroAndPastEnd() {
        XCTAssertEqual(ViewportMath.clampViewportStart(-5, audioDuration: 100, viewportDuration: 20), 0)
        XCTAssertEqual(ViewportMath.clampViewportStart(90, audioDuration: 100, viewportDuration: 20), 80)
        XCTAssertEqual(ViewportMath.clampViewportStart(15, audioDuration: 100, viewportDuration: 20), 15)
    }

    func testClampViewportStart_WhenAudioFitsInViewport_IsZero() {
        XCTAssertEqual(ViewportMath.clampViewportStart(12, audioDuration: 10, viewportDuration: 20), 0)
        XCTAssertEqual(ViewportMath.clampViewportStart(4, audioDuration: 0, viewportDuration: 20), 0)
    }

    func testPlayheadX_MapsTimeInsideViewportToCanvasX() throws {
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.playheadX(time: 10, viewportStart: 10, viewportDuration: 20, audioDuration: 100, width: 200)),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.playheadX(time: 20, viewportStart: 10, viewportDuration: 20, audioDuration: 100, width: 200)),
            100,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.playheadX(time: 30, viewportStart: 10, viewportDuration: 20, audioDuration: 100, width: 200)),
            200,
            accuracy: 0.0001
        )
    }

    func testPlayheadX_UsesClampedWindowNearAudioEnd() throws {
        // Viewport 90+20 is clipped to 90...100, so t=95 is halfway.
        XCTAssertEqual(
            try XCTUnwrap(ViewportMath.playheadX(time: 95, viewportStart: 90, viewportDuration: 20, audioDuration: 100, width: 200)),
            100,
            accuracy: 0.0001
        )
    }

    func testPlayheadX_ReturnsNilWhenTimeIsOutsideWindow() {
        XCTAssertNil(ViewportMath.playheadX(time: 5, viewportStart: 10, viewportDuration: 20, audioDuration: 100, width: 200))
        XCTAssertNil(ViewportMath.playheadX(time: 35, viewportStart: 10, viewportDuration: 20, audioDuration: 100, width: 200))
    }

    func testPlayheadX_ReturnsNilWhenWindowIsInvalid() {
        XCTAssertNil(ViewportMath.playheadX(time: 5, viewportStart: 0, viewportDuration: 0, audioDuration: 100, width: 200))
        XCTAssertNil(ViewportMath.playheadX(time: 5, viewportStart: 0, viewportDuration: 20, audioDuration: 0, width: 200))
    }

    func testFollowedStart_WhilePlaying_SnapsToCenteredTarget() {
        // Previous start lagged behind; playback should hard-snap, not ease.
        let next = ViewportMath.followedStart(
            currentStart: 10,
            currentTime: 40,
            duration: 120,
            viewportDuration: 20,
            isPlaying: true,
            snap: false
        )
        XCTAssertEqual(next, 30, accuracy: 0.0001)
    }

    func testFollowedStart_WhenSnapRequested_SnapsEvenIfPaused() {
        let next = ViewportMath.followedStart(
            currentStart: 0,
            currentTime: 40,
            duration: 120,
            viewportDuration: 20,
            isPlaying: false,
            snap: true
        )
        XCTAssertEqual(next, 30, accuracy: 0.0001)
    }

    func testFollowedStart_WhenPausedWithoutSnap_KeepsCurrentStart() {
        let next = ViewportMath.followedStart(
            currentStart: 12,
            currentTime: 40,
            duration: 120,
            viewportDuration: 20,
            isPlaying: false,
            snap: false
        )
        XCTAssertEqual(next, 12, accuracy: 0.0001)
    }

    func testFollowedStart_WhenDetachedWhilePlaying_KeepsCurrentStart() {
        let next = ViewportMath.followedStart(
            currentStart: 12,
            currentTime: 40,
            duration: 120,
            viewportDuration: 20,
            isPlaying: true,
            snap: false,
            detached: true
        )
        XCTAssertEqual(next, 12, accuracy: 0.0001)
    }

    func testFollowedStart_WhenDetachedAndSnapRequested_Recenters() {
        let next = ViewportMath.followedStart(
            currentStart: 12,
            currentTime: 40,
            duration: 120,
            viewportDuration: 20,
            isPlaying: true,
            snap: true,
            detached: true
        )
        XCTAssertEqual(next, 30, accuracy: 0.0001)
    }

    func testShouldPublishTransport_WhilePlaying_ThrottlesToInterval() {
        XCTAssertTrue(ViewportMath.shouldPublishTransport(now: 1.00, lastPublishedAt: 0, isPlaying: true))
        XCTAssertFalse(ViewportMath.shouldPublishTransport(now: 1.05, lastPublishedAt: 1.00, isPlaying: true))
        XCTAssertTrue(ViewportMath.shouldPublishTransport(now: 1.10, lastPublishedAt: 1.00, isPlaying: true))
    }

    func testShouldPublishTransport_WhenPaused_AlwaysPublishes() {
        XCTAssertTrue(ViewportMath.shouldPublishTransport(now: 1.01, lastPublishedAt: 1.00, isPlaying: false))
    }

    func testStripWindow_CentersThreeViewportsOnAnchor() {
        let window = WaveformStripMath.stripWindow(anchorTime: 60, viewportDuration: 20, audioDuration: 600)
        XCTAssertEqual(window.start, 30, accuracy: 0.0001)
        XCTAssertEqual(window.end, 90, accuracy: 0.0001)
    }

    func testStripWindow_ClampsToAudioBounds() {
        let nearStart = WaveformStripMath.stripWindow(anchorTime: 5, viewportDuration: 20, audioDuration: 600)
        XCTAssertEqual(nearStart.start, 0, accuracy: 0.0001)
        XCTAssertEqual(nearStart.end, 60, accuracy: 0.0001)

        let nearEnd = WaveformStripMath.stripWindow(anchorTime: 590, viewportDuration: 20, audioDuration: 600)
        XCTAssertEqual(nearEnd.start, 540, accuracy: 0.0001)
        XCTAssertEqual(nearEnd.end, 600, accuracy: 0.0001)
    }

    func testImageOffsetX_PlacesVisibleStartAtViewLeadingEdge() {
        // Mid-track: viewport [20, 40] inside strip [0, 60], view 200pt of 600pt strip.
        let offset = WaveformStripMath.imageOffsetX(
            visibleStart: 20,
            stripStart: 0,
            stripDuration: 60,
            stripPixelWidth: 600
        )
        XCTAssertEqual(offset, -200, accuracy: 0.0001)
    }

    func testImageOffsetX_NearTrackStart_MatchesClampedViewport() throws {
        // Playhead at t=5 with 20s viewport clamps to start=0 (ruler window), not hard-center.
        let visibleStart = ViewportMath.viewportStart(currentTime: 5, duration: 600, viewportDuration: 20)
        XCTAssertEqual(visibleStart, 0, accuracy: 0.0001)

        let offset = WaveformStripMath.imageOffsetX(
            visibleStart: visibleStart,
            stripStart: 0,
            stripDuration: 60,
            stripPixelWidth: 600
        )
        XCTAssertEqual(offset, 0, accuracy: 0.0001)

        let playheadX = try XCTUnwrap(
            ViewportMath.playheadX(
                time: 5,
                viewportStart: visibleStart,
                viewportDuration: 20,
                audioDuration: 600,
                width: 200
            )
        )
        // Ruler tick at t=5 and CA playhead must share the same x.
        XCTAssertEqual(playheadX, 50, accuracy: 0.0001)
        let tickX = ((5.0 - visibleStart) / 20.0) * 200.0
        XCTAssertEqual(tickX, playheadX, accuracy: 0.0001)
    }

    func testNeedsPrefetch_WhenPlayheadNearsStripEdge() {
        XCTAssertTrue(WaveformStripMath.needsPrefetch(currentTime: 10, stripStart: 0, stripDuration: 60))
        XCTAssertFalse(WaveformStripMath.needsPrefetch(currentTime: 30, stripStart: 0, stripDuration: 60))
        XCTAssertTrue(WaveformStripMath.needsPrefetch(currentTime: 50, stripStart: 0, stripDuration: 60))
    }

    func testRulerTickIntervals_TwoHourFit_KeepsLabelsSpaced() {
        // Full-fit 2h on a typical editor width must not pack labels every 2 minutes.
        let intervals = ViewportMath.rulerTickIntervals(viewportDuration: 7200, width: 1000)
        let labelSpacing = 1000 * (intervals.label / 7200)
        XCTAssertGreaterThanOrEqual(labelSpacing, 70, "labels need room; got \(intervals.label)s → \(labelSpacing)pt")
        XCTAssertGreaterThanOrEqual(intervals.label, 600)
        XCTAssertLessThanOrEqual(intervals.half, intervals.major)
        XCTAssertLessThanOrEqual(intervals.major, intervals.label)
    }

    func testRulerTickIntervals_ShortViewport_StaysFineGrained() {
        let intervals = ViewportMath.rulerTickIntervals(viewportDuration: 20, width: 1000)
        XCTAssertLessThanOrEqual(intervals.label, 5)
    }

    func testRulerTickIntervals_NarrowWidth_UsesCoarserLabels() {
        let wide = ViewportMath.rulerTickIntervals(viewportDuration: 600, width: 1200)
        let narrow = ViewportMath.rulerTickIntervals(viewportDuration: 600, width: 300)
        XCTAssertGreaterThanOrEqual(narrow.label, wide.label)
    }

    func testMarkerLayoutX_TracksTimeInsideViewport() throws {
        let before = try XCTUnwrap(
            ViewportMath.markerLayoutX(
                time: 15,
                viewportStart: 10,
                viewportDuration: 20,
                audioDuration: 100,
                width: 200
            )
        )
        let after = try XCTUnwrap(
            ViewportMath.markerLayoutX(
                time: 20,
                viewportStart: 10,
                viewportDuration: 20,
                audioDuration: 100,
                width: 200
            )
        )
        XCTAssertEqual(before, 50, accuracy: 0.0001)
        XCTAssertEqual(after, 100, accuracy: 0.0001)
        XCTAssertGreaterThan(after, before)
    }

    func testMarkerLayoutX_NilWhenOutsideViewport() {
        XCTAssertNil(
            ViewportMath.markerLayoutX(
                time: 5,
                viewportStart: 10,
                viewportDuration: 20,
                audioDuration: 100,
                width: 200
            )
        )
    }
}
