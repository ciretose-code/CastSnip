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
}
