# Core Animation Waveform Detail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the detail waveform SwiftUI `Canvas` with an AppKit `NSView` + Core Animation layers so playback scrolls a pre-baked strip instead of redrawing bars every frame.

**Architecture:** `WaveformView` keeps overview/ruler/peak loading. Detail becomes `WaveformDetailRepresentable` → `WaveformDetailSurface` (`NSView`) with regions, waveform, markers, played-wash, and playhead layers. A CGContext baker produces strip images; follow mode uses `NSView.displayLink` to update layer positions only.

**Tech Stack:** Swift, AppKit, Core Animation (`CALayer`), Core Graphics, SwiftUI `NSViewRepresentable`, existing `WaveformPeakStore` / `WaveformSampling` / `WaveformStripMath`.

**Spec:** `docs/superpowers/specs/2026-10-04-core-animation-waveform-design.md`

## Global Constraints

- macOS app only; deployment target as in Xcode project (macOS 26.6 on this machine’s project settings).
- Do not change ID3, encode, or chapter model behavior.
- Overview strip and time ruler stay SwiftUI `Canvas` in v1.
- Title pills on the detail surface are optional; v1 may omit them (pause can live without pills).
- New app sources must be added to `CastSnip.xcodeproj/project.pbxproj` (app target is not a synchronized root).
- Team ID / sandbox unchanged.
- Prefer TDD for pure math; manual checklist for gestures and visual follow mode.

## Review Focus

- Playing near audio start/end: strip clamps; playhead stays visible; no crash or blank forever.
- Resize window while playing: strip rebakes at new size/scale; no blurry 1x contents on Retina.
- Marker drag while paused then play: boundaries match baked markers after rebake.
- Scroll-wheel pan while playing: detaches follow; waveform no longer forced-center until re-attach.
- Seek via overview while playing: re-attaches follow and recenters.

---

## File map

| File | Responsibility |
|------|----------------|
| `CastSnip/ViewportMath.swift` | Restore/keep `WaveformStripMath` (window, offset, prefetch) |
| `CastSnip/WaveformStripBaker.swift` | Pure-ish CG bake of regions+bars+markers → `CGImage` / `NSImage` |
| `CastSnip/WaveformDetailSurface.swift` | `NSView`, layer tree, gestures, display link, follow/free |
| `CastSnip/WaveformView.swift` | Host representable; remove detail `Canvas` path |
| `CastSnip.xcodeproj/project.pbxproj` | Compile new Swift files |
| `CastSnipTests/ViewportMathTests.swift` | Strip math tests (restore if missing) |
| `CastSnipTests/WaveformStripBakerTests.swift` | Baker smoke: non-nil image, expected pixel size |

---

### Task 1: Restore strip math + tests

**Files:**
- Modify: `CastSnip/ViewportMath.swift` (append `WaveformStripMath` if absent)
- Modify: `CastSnipTests/ViewportMathTests.swift` (strip tests)
- Test: `CastSnipTests/ViewportMathTests.swift`

**Interfaces:**
- Produces: `WaveformStripMath.stripWindow(anchorTime:viewportDuration:audioDuration:) -> Window`, `imageOffsetX(currentTime:stripStart:stripDuration:stripPixelWidth:viewWidth:) -> CGFloat`, `needsPrefetch(currentTime:stripStart:stripDuration:) -> Bool`, constants `widthInViewports = 3`, `prefetchEdgeFraction = 0.25`

- [ ] **Step 1: Confirm `WaveformStripMath` is missing after the strip revert**

Run: `rg -n "enum WaveformStripMath" CastSnip/ViewportMath.swift`  
Expected: no matches (math was removed with the SwiftUI strip revert).

- [ ] **Step 2: Write failing tests** (append to `ViewportMathTests.swift`)

```swift
func testStripWindow_CentersThreeViewportsOnAnchor() {
    let window = WaveformStripMath.stripWindow(anchorTime: 60, viewportDuration: 20, audioDuration: 600)
    XCTAssertEqual(window.start, 30, accuracy: 0.0001)
    XCTAssertEqual(window.end, 90, accuracy: 0.0001)
}

func testStripWindow_ClampsToAudioBounds() {
    let nearStart = WaveformStripMath.stripWindow(anchorTime: 5, viewportDuration: 20, audioDuration: 600)
    XCTAssertEqual(nearStart.start, 0, accuracy: 0.0001)
    XCTAssertEqual(nearStart.end, 60, accuracy: 0.0001)
}

func testImageOffsetX_PlacesCurrentTimeAtViewCenter() {
    let offset = WaveformStripMath.imageOffsetX(
        currentTime: 30, stripStart: 0, stripDuration: 60,
        stripPixelWidth: 600, viewWidth: 200
    )
    XCTAssertEqual(offset, -200, accuracy: 0.0001)
}

func testNeedsPrefetch_WhenPlayheadNearsStripEdge() {
    XCTAssertTrue(WaveformStripMath.needsPrefetch(currentTime: 10, stripStart: 0, stripDuration: 60))
    XCTAssertFalse(WaveformStripMath.needsPrefetch(currentTime: 30, stripStart: 0, stripDuration: 60))
    XCTAssertTrue(WaveformStripMath.needsPrefetch(currentTime: 50, stripStart: 0, stripDuration: 60))
}
```

- [ ] **Step 3: Run tests — expect compile/link failure**

Run: `xcodebuild -project CastSnip.xcodeproj -scheme CastSnip -destination "platform=macOS" -only-testing:CastSnipTests/ViewportMathTests test`

- [ ] **Step 4: Implement `WaveformStripMath` at end of `ViewportMath.swift`**

Match the API used in the tests (same as the reverted implementation): 3× viewport span, clamp to audio, `imageOffsetX = viewWidth/2 - progress*stripPixelWidth`, prefetch outside middle 50%.

- [ ] **Step 5: Re-run ViewportMathTests — expect PASS**

- [ ] **Step 6: Commit**

```bash
git add CastSnip/ViewportMath.swift CastSnipTests/ViewportMathTests.swift
git commit -m "Restore WaveformStripMath for the CA detail surface."
```

---

### Task 2: WaveformStripBaker

**Files:**
- Create: `CastSnip/WaveformStripBaker.swift`
- Modify: `CastSnip.xcodeproj/project.pbxproj`
- Test: `CastSnipTests/WaveformStripBakerTests.swift`

**Interfaces:**
- Consumes: `WaveformSampling.viewportPeaks`, `WaveformPeakStore` tile constants, `WaveformView.Marker`
- Produces:

```swift
enum WaveformStripBaker {
    struct Input: Sendable {
        var size: CGSize           // point size of strip
        var scale: CGFloat
        var stripStart: TimeInterval
        var stripDuration: TimeInterval
        var audioDuration: TimeInterval
        var overview: [Float]
        var overviewBucketDuration: TimeInterval
        var tiles: [Int: [Float]]
        var markers: [WaveformView.Marker] // Marker must be Sendable or pass a bake-DTO
    }
    nonisolated static func bake(_ input: Input) -> CGImage?
}
```

If `WaveformView.Marker` is not `Sendable`, define `WaveformStripBaker.MarkerDTO` (time, end, color components, selected, locked, lineWidth) and map at the call site.

- [ ] **Step 1: Write failing baker test**

```swift
@Test func bakeProducesImageAtScaledPixelSize() {
    let input = WaveformStripBaker.Input(
        size: CGSize(width: 300, height: 100),
        scale: 2,
        stripStart: 0, stripDuration: 30, audioDuration: 60,
        overview: Array(repeating: Float(0.5), count: 100),
        overviewBucketDuration: 0.6,
        tiles: [:],
        markers: []
    )
    let image = WaveformStripBaker.bake(input)
    #expect(image != nil)
    #expect(image!.width == 600)
    #expect(image!.height == 200)
}
```

- [ ] **Step 2: Run — expect fail (type missing)**

- [ ] **Step 3: Implement baker** — CGBitmapContext, flip to top-left, draw chapter fills, gray bars (no playhead), marker lines/handles. Use `NSColor.labelColor` / resolved marker colors. Set no title pills.

- [ ] **Step 4: Add file to pbxproj** (PBXBuildFile + PBXFileReference + group + Sources), next to `WaveformSampling.swift`.

- [ ] **Step 5: Run baker test — PASS**

- [ ] **Step 6: Commit**

```bash
git add CastSnip/WaveformStripBaker.swift CastSnip.xcodeproj/project.pbxproj CastSnipTests/WaveformStripBakerTests.swift
git commit -m "Add CG baker for waveform detail strips."
```

---

### Task 3: WaveformDetailSurface scaffold + free viewport

**Files:**
- Create: `CastSnip/WaveformDetailSurface.swift` (includes `WaveformDetailRepresentable`)
- Modify: `CastSnip.xcodeproj/project.pbxproj`
- Modify: `CastSnip/WaveformView.swift` (swap detail `Canvas` for representable; keep Canvas temporarily behind a flag only if needed — prefer full swap)

**Interfaces:**
- Consumes: baker, `WaveformStripMath`, peaks fields from `WaveformView`
- Produces: `WaveformDetailRepresentable` with properties:

```swift
struct WaveformDetailRepresentable: NSViewRepresentable {
    var viewportStart: TimeInterval
    var viewportDuration: TimeInterval
    var currentTime: TimeInterval
    var isPlaying: Bool
    var audioDuration: TimeInterval
    var overview: [Float]
    var overviewBucketDuration: TimeInterval
    var tiles: [Int: [Float]]
    var markers: [WaveformView.Marker]
    var onSeek: (TimeInterval) -> Void
    var onViewportPan: (TimeInterval) -> Void
    var onMarkerMove: (UUID, TimeInterval) -> Void
    var onMarkerMoveEnded: (UUID) -> Void
    var onAddChapter: (TimeInterval) -> Void
    var onZoom: (Bool) -> Void
}
```

`WaveformDetailSurface` methods used by representable:

```swift
func applyModel(_ model: WaveformDetailModel) // struct bundling the above value fields
```

- [ ] **Step 1: Create `NSView` subclass** with `wantsLayer = true`, five sublayers (`regions`, `waveform`, `markers`, `playedWash`, `playhead`), `contentsScale` from window backing scale.

- [ ] **Step 2: On bounds change / model change (free mode)** — compute strip window anchored to `viewportStart + viewportDuration/2` (or playhead if following — Task 4), bake async, set `waveformLayer.contents` (+ bake regions/markers into separate images or same composite for v1 simplicity: **v1 may bake regions+bars+markers into one `waveformLayer` image** and keep wash+playhead as live layers only — simpler, still meets “no per-frame bar redraw”). Spec allows region/marker rebake on change; single composite strip is OK for Task 3.

**v1 simplification (allowed):** one baked image = regions + bars + markers; live layers = wash + playhead only.

- [ ] **Step 3: Position content** — `waveformLayer.frame` = strip pixel size in points; `position` / `frame.origin.x` from `WaveformStripMath.imageOffsetX` so the visible window matches `viewportStart`… (for free mode, treat “currentTime” in offset math as `viewportStart + viewportDuration/2` so the viewport center maps to view center).

- [ ] **Step 4: Wire seek** — `mouseDown`/`dragged` → time at x → `onSeek`. Double-click → `onAddChapter`. Scroll wheel → `onViewportPan` using `ViewportMath.panDeltaSeconds`.

- [ ] **Step 5: Replace detail in `WaveformView`** with representable; delete unused detail Canvas helpers only after compile proves unused (or leave private helpers until Task 5 cleanup).

- [ ] **Step 6: Manual smoke** — run app, open intro, confirm waveform appears, click seek works while paused.

- [ ] **Step 7: Commit**

```bash
git add CastSnip/WaveformDetailSurface.swift CastSnip/WaveformView.swift CastSnip.xcodeproj/project.pbxproj
git commit -m "Host detail waveform on a Core Animation NSView."
```

---

### Task 4: Follow mode + display link

**Files:**
- Modify: `CastSnip/WaveformDetailSurface.swift`
- Modify: `CastSnip/WaveformView.swift` (pass `isPlaying` / time; optional detach callback later)

**Interfaces:**
- Produces: follow mode when `isPlaying && !isDetached`; `NSView.displayLink` updates positions each frame from `currentTime` without rebaking.

- [ ] **Step 1: Add `isDetached` flag** — set true on scroll-wheel pan while `isPlaying`; clear when `isPlaying` becomes true from false, or when `viewportStart` jumps from overview (representable can pass `followEpoch` int bumped by WaveformView on overview seek).

Simpler v1 rule matching ContentView hard-center while playing: **`isDetached` ignored — while `isPlaying`, always follow** (ContentView already overwrites viewport). Document that pan-while-playing may fight follow until ContentView detach exists; acceptable for Task 4.

- [ ] **Step 2: Start/stop `displayLink` on the view** when `isPlaying` toggles (`view.displayLink(target:selector:)`), invalidate on `removeFromSuperview` / deinit.

- [ ] **Step 3: On display-link fire** — if playing, set content offset from `currentTime` via `imageOffsetX`; playhead layer at `bounds.midX`; wash width = midX. **Do not bake.**

- [ ] **Step 4: Prefetch** — if `needsPrefetch`, kick async bake anchored at `currentTime`; swap contents on main when done (generation token).

- [ ] **Step 5: Manual** — play intro at 10s viewport; confirm smooth scroll and no bar shimmer; pause restores free seek.

- [ ] **Step 6: Commit**

```bash
git add CastSnip/WaveformDetailSurface.swift
git commit -m "Scroll the CA waveform strip with a view display link."
```

---

### Task 5: Interaction parity + Canvas cleanup

**Files:**
- Modify: `CastSnip/WaveformDetailSurface.swift`
- Modify: `CastSnip/WaveformView.swift`

- [ ] **Step 1: Marker hit-testing** — port `markerGrabDistance` (6pt); drag calls `onMarkerMove` / `onMarkerMoveEnded`; rebake after drag end.

- [ ] **Step 2: Magnify gesture** on the NSView → `onZoom`.

- [ ] **Step 3: Hover cursor** near unlocked markers → `resizeLeftRight`.

- [ ] **Step 4: Remove dead detail Canvas drawing** from `WaveformView` (`liveDetail`, `drawWaveform`, `drawRegions`, `drawMarkers`, `drawPlayedWash`, `drawPlayhead`, `drawFixedCenterPlayhead` if any).

- [ ] **Step 5: Run full unit tests**

Run: `xcodebuild -project CastSnip.xcodeproj -scheme CastSnip -destination "platform=macOS" -only-testing:CastSnipTests test`  
Expected: TEST SUCCEEDED

- [ ] **Step 6: Commit + push PR branch**

```bash
git add CastSnip/WaveformDetailSurface.swift CastSnip/WaveformView.swift
git commit -m "Finish CA detail gestures and remove Canvas detail path."
git push
```

---

## Spec coverage checklist

| Spec item | Task |
|-----------|------|
| CA detail always (B) | 3–5 |
| Layer stack / scroll not redraw | 3–4 (composite strip + live wash/playhead) |
| Strip math 3× / prefetch 25% | 1, 4 |
| Gestures parity | 3 (seek/pan), 5 (markers/zoom/hover) |
| `NSView.displayLink` | 4 |
| Overview/ruler unchanged | 3 (WaveformView keeps them) |
| No ID3/encode changes | all |
| HiDPI bake | 2–3 (`scale` / `contentsScale`) |
| Start/end clamp | 1 tests + baker window |

## Execution

Native execution in this session (user said “go”).
