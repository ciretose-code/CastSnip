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
}
