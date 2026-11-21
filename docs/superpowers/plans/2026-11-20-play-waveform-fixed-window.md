# Play Waveform Fixed Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the zoom waveform a short fixed window whose playhead walks across it while playing, paging only when the playhead leaves the window.

**Architecture:** Change `ViewportMath.followedStart` from continuous center-follow to keep-or-page-on-exit. Cap the detail strip height in `WaveformView`. Stop `WaveformDetailSurface` from anchoring strip bakes on the live playhead so the baked strip stays tied to the visible window.

**Tech Stack:** Swift, SwiftUI, AppKit/Core Animation waveform surface, XCTest (`CastSnipTests`).

**Spec:** `docs/superpowers/specs/2026-11-20-play-waveform-fixed-window-design.md`

## Global Constraints

- Zoom strip fixed height: **56pt** (spec).
- Page inset: playhead lands at **10%** from the entering edge after a page (spec builder call).
- Full-audio overview height/behavior unchanged (**32pt**).
- Detached pan while playing still freezes auto-paging until snap / overview seek / play-from-stopped.
- One-shot snap (play start, overview seek, chapter jump, zoom) still hard-centers via existing `viewportStart(currentTime:…)`.

## Review Focus

- Playhead exactly on the right edge of the window — treat as still inside (no flicker page); page only when `currentTime > viewportStart + viewportDuration`.
- Playhead exactly on the left edge — still inside; page only when `currentTime < viewportStart`.
- Near end of file after a right-exit page — `clampViewportStart` must not leave playhead off-screen when possible.
- Detached + playhead outside window — must **not** page until snap.
- Zoom / viewportDuration change while playing — strip rebakes for new duration; paging math uses the new duration immediately.

---

## File map

| File | Role |
|------|------|
| `CastSnip/ViewportMath.swift` | `followedStart` keep/page logic + `pageInsetFraction` |
| `CastSnipTests/ViewportMathTests.swift` | Replace center-follow expectations; add keep/page tests |
| `CastSnip/WaveformView.swift` | Fixed 56pt detail height |
| `CastSnip/WaveformDetailSurface.swift` | Strip bake anchor = viewport center always (ignore playhead follow for bake) |
| `CastSnip/ContentView.swift` | Only if `followsPlayhead` wiring needs a one-line comment/clarity; prefer no behavior change beyond math |

---

### Task 1: Page-on-exit viewport math

**Files:**
- Modify: `CastSnip/ViewportMath.swift` (`followedStart` and its doc comment)
- Modify: `CastSnipTests/ViewportMathTests.swift` (followedStart tests)

**Interfaces:**
- Consumes: existing `viewportStart(currentTime:duration:viewportDuration:)`, `clampViewportStart(audioDuration:viewportDuration:)`
- Produces: `ViewportMath.pageInsetFraction: Double` (= `0.1`); `followedStart(...)` with same signature as today, new semantics:
  - `snap` → centered `viewportStart` (unchanged)
  - `detached && !snap` → keep clamped `currentStart` (unchanged)
  - `!isPlaying && !snap` → keep `currentStart` (unchanged)
  - playing, not detached, not snap → if `currentTime` in `[currentStart, currentStart + viewportDuration]` keep `currentStart`; if `currentTime > end` return `clampViewportStart(currentTime - pageInsetFraction * viewportDuration, …)`; if `currentTime < currentStart` return `clampViewportStart(currentTime - (1 - pageInsetFraction) * viewportDuration, …)`

- [ ] **Step 1: Rewrite the failing / updated tests**

Replace `testFollowedStart_WhilePlaying_SnapsToCenteredTarget` with keep + page cases:

```swift
func testFollowedStart_WhilePlaying_PlayheadInsideWindow_KeepsCurrentStart() {
    let next = ViewportMath.followedStart(
        currentStart: 20,
        currentTime: 30,
        duration: 120,
        viewportDuration: 20,
        isPlaying: true,
        snap: false
    )
    XCTAssertEqual(next, 20, accuracy: 0.0001)
}

func testFollowedStart_WhilePlaying_PlayheadExitsRight_PagesWithInset() {
    // Window [10, 30]; time 40 → start = 40 - 0.1*20 = 38
    let next = ViewportMath.followedStart(
        currentStart: 10,
        currentTime: 40,
        duration: 120,
        viewportDuration: 20,
        isPlaying: true,
        snap: false
    )
    XCTAssertEqual(next, 38, accuracy: 0.0001)
}

func testFollowedStart_WhilePlaying_PlayheadExitsLeft_PagesWithInset() {
    // Window [40, 60]; time 30 → start = 30 - 0.9*20 = 12
    let next = ViewportMath.followedStart(
        currentStart: 40,
        currentTime: 30,
        duration: 120,
        viewportDuration: 20,
        isPlaying: true,
        snap: false
    )
    XCTAssertEqual(next, 12, accuracy: 0.0001)
}

func testFollowedStart_WhilePlaying_PlayheadOnRightEdge_KeepsCurrentStart() {
    let next = ViewportMath.followedStart(
        currentStart: 10,
        currentTime: 30,
        duration: 120,
        viewportDuration: 20,
        isPlaying: true,
        snap: false
    )
    XCTAssertEqual(next, 10, accuracy: 0.0001)
}
```

Keep existing snap / paused / detached tests as-is (`testFollowedStart_WhenSnapRequested_…`, `WhenPausedWithoutSnap_…`, `WhenDetachedWhilePlaying_…`, `WhenDetachedAndSnapRequested_…`).

- [ ] **Step 2: Run tests to verify old center-follow expectation fails / new tests fail**

Run: `xcodebuild -project CastSnip.xcodeproj -scheme CastSnip -destination "platform=macOS" -only-testing:CastSnipTests/ViewportMathTests test`

Expected: FAIL on the new while-playing keep/page tests (still center-follows → e.g. time 30/window 20 → start 20 instead of keep 20, or right-exit yields 30 instead of 38).

- [ ] **Step 3: Implement page-on-exit in `followedStart`**

In `CastSnip/ViewportMath.swift`: add `static let pageInsetFraction: Double = 0.1`. Update `followedStart` doc comment to describe keep/page (not hard-center while playing). Implement the semantics in Interfaces. Do not change the function signature.

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project CastSnip.xcodeproj -scheme CastSnip -destination "platform=macOS" -only-testing:CastSnipTests/ViewportMathTests test`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add CastSnip/ViewportMath.swift CastSnipTests/ViewportMathTests.swift
git commit -m "$(cat <<'EOF'
fix: page zoom viewport when playhead leaves the window

Replace continuous center-follow while playing so the strip stays put until the playhead exits.
EOF
)"
```

---

### Task 2: Fixed zoom height + viewport-anchored strip bake

**Files:**
- Modify: `CastSnip/WaveformView.swift` (detail `.frame`)
- Modify: `CastSnip/WaveformDetailSurface.swift` (`stripAnchor`)

**Interfaces:**
- Consumes: Task 1 `followedStart` (ContentView already calls it; no API change)
- Produces: detail strip laid out at **56pt**; `stripAnchor` always `model.viewportStart + model.viewportDuration / 2` (never `model.currentTime`), so bake/prefetch track the visible window even when `followsPlayhead` is still true from ContentView

- [ ] **Step 1: Cap detail height**

In `WaveformView.swift`, replace detail `.frame(maxHeight: .infinity)` with `.frame(height: 56)`. Add `private let detailHeight: CGFloat = 56` next to `overviewHeight` / `rulerHeight` and use it.

- [ ] **Step 2: Viewport-center strip anchor**

In `WaveformDetailSurface.swift`, change `stripAnchor` to always return `model.viewportStart + model.viewportDuration / 2` (remove the `followsPlayhead && isPlaying` branch). Leave `followsPlayhead` on the model for now (unused for bake); do not expand scope to delete the property unless the compiler forces it.

- [ ] **Step 3: Build + run waveform-related tests**

Run: `xcodebuild -project CastSnip.xcodeproj -scheme CastSnip -destination "platform=macOS" -only-testing:CastSnipTests/ViewportMathTests -only-testing:CastSnipTests/WaveformStripBakerTests -only-testing:CastSnipTests/WaveformSamplingTests -only-testing:CastSnipTests/WaveformMarkerTests test`

Expected: PASS (and the macOS target compiles).

- [ ] **Step 4: Manual check (implementer)**

Launch CastSnip, play audio: zoom strip stays short; playhead walks; window pages at the edge; pan-while-play detaches; overview seek snaps; full-audio strip unchanged.

- [ ] **Step 5: Commit**

```bash
git add CastSnip/WaveformView.swift CastSnip/WaveformDetailSurface.swift
git commit -m "$(cat <<'EOF'
fix: shrink zoom strip and bake it to the visible window

Cap detail height at 56pt and stop anchoring strip bakes on the live playhead.
EOF
)"
```

---

## Self-review notes

- Spec goals (fixed height, no continuous follow, page on exit, detach, overview unchanged) map to Tasks 1–2.
- Review Focus edge/detached cases covered by Task 1 tests; near-EOF relies on existing `clampViewportStart` used by the new page branches.
- No new files; signatures unchanged for `ContentView`.
