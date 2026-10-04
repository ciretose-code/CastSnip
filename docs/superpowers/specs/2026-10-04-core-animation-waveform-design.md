# Core Animation waveform detail surface

**Date:** 2026-10-04  
**Status:** Approved for planning (approach B)  
**Context:** Playback visuals still stutter because SwiftUI `Canvas` redraws a scrolling detail waveform every display frame. Display-link timing and lighter Canvas polish helped but hit a ceiling. Strip-sliding via SwiftUI `Image` was tried and reverted.

## Goal

Replace the detail waveform’s SwiftUI `Canvas` stack with an AppKit `NSView` backed by Core Animation layers so playback scrolls pre-baked layer contents (GPU compositing) instead of re-laying out bars every frame. Overview, ruler, chapter list, and peak decoding stay as they are.

## Non-goals (v1)

- Core Animation for the overview strip or time ruler
- Metal custom shaders
- Isolating `AudioPlayerManager` / `@Published currentTime` from `ContentView` (follow-up once detail is smooth)
- Changing ID3, encode, or chapter model behavior

## Approach (B)

**CA detail always.** SwiftUI hosts a single `NSViewRepresentable` for the detail pane in play and pause. Play vs pause is “follow mode” vs “free viewport,” not a renderer switch.

## Architecture

```
WaveformView (SwiftUI)
├── overview (existing Canvas + equatable base)
├── Divider
├── WaveformDetailRepresentable  ← NEW
│     └── WaveformDetailSurface : NSView
│           ├── regionsLayer
│           ├── waveformLayer      (CALayer.contents = CGImage strip)
│           ├── markersLayer
│           ├── playedWashLayer
│           └── playheadLayer
└── ruler Canvas (existing)
```

`WaveformPeakStore` / `WaveformSampling` remain the source of peaks. A shared CGContext baker produces strip images for `waveformLayer.contents` (and region/marker layers as drawn bitmaps or shape layers).

### Layer responsibilities

| Layer | Role | Rebuild when | Per follow-mode frame |
|-------|------|--------------|------------------------|
| `regionsLayer` | Chapter color fills | markers, selection, strip window | no |
| `waveformLayer` | Bar waveform strip | peaks, viewport duration, view size, strip window | **position / transform only** |
| `markersLayer` | Boundary lines + handles | markers; optionally during drag | no (except active drag) |
| `playedWashLayer` | CastSnip-blue tint left of playhead | — | bounds / position |
| `playheadLayer` | Line + cap | — | x (center in follow; tracks time when free) |

### Strip geometry

Reuse `WaveformStripMath` concepts (already in `ViewportMath.swift`):

- Strip width ≈ **3×** `viewportDuration`, anchored near the visible window / playhead
- Prefetch when playhead progress within the strip enters the outer **25%**
- Bake at `backingScaleFactor`
- Bake off the main thread; assign `contents` on the main thread
- Optional short crossfade on swap; v1 may hard-swap if simpler

### Follow vs free

- **Follow** (`isPlaying` and not user-detached): playhead fixed at horizontal center; scroll content layers so `currentTime` maps to midX; ignore manual pan until detach.
- **Free** (paused, or playing after user pan): viewport pan / seek update layer positions from `viewportStart` + `viewportDuration`; playhead x tracks `currentTime` within the window.
- Detach on scroll-wheel pan while playing; re-attach on overview seek, explicit snap, or when appropriate after play resumes (match current `ContentView` intent: hard-center while playing unless suppressed).

### Interaction (on `WaveformDetailSurface`)

Parity with today’s detail gestures:

- Click / drag empty area → `onSeek`
- Drag near boundary → `onMarkerMove` / `onMarkerMoveEnded`
- Scroll wheel → `onViewportPan` (free / detach)
- Magnify / pinch → `onZoom`
- Double-click → `onAddChapter`
- Hover near boundary → resize cursor

Hit-testing uses the same time↔x mapping as `ViewportMath` / current `WaveformView` helpers.

### Display clock

- Prefer `NSView.displayLink(target:selector:)` on the detail surface (tracks the view’s screen; replaces relying solely on player-driven SwiftUI invalidation for scroll).
- While following, each tick: read playhead time (from injected clock or callback), update layer positions only.
- `AudioPlayerManager` can keep publishing for transport UI; v1 does not require splitting the observable clock.

## SwiftUI integration

- Replace the detail `ZStack` of `Canvas`es in `WaveformView` with `WaveformDetailRepresentable`.
- Pass: `viewportStart`, `viewportDuration`, `currentTime`, `isPlaying`, peaks snapshot (overview/tiles/durations), `markers`, and the existing callbacks.
- Representable `updateNSView` pushes model changes; must not rebuild strip images unless inputs that affect the bake actually change.

## Phased delivery

1. **Scaffold + static bake** — representable, layer tree, bake visible strip, seek/pan without follow-mode scroll smoothness target.
2. **Follow mode** — display-link driven layer scroll; fixed center playhead; played wash.
3. **Prefetch + interaction parity** — edge prefetch, marker drag, zoom, hover cursors; remove dead Canvas detail paths.

Each phase should leave the app usable (open file, play, seek, edit chapters).

## Testing

- Unit-test strip/follow math (extend `WaveformStripMath` / `ViewportMath` as needed): window, offset, prefetch, playhead x.
- Manual: play long file at 10s/30s viewport; pan while paused; drag markers; zoom; overview jump; play near start/end (strip clamp).
- No requirement for UI tests of layer positions in v1.

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| First-bake blank frame | Placeholder or keep last contents; kick bake on appear |
| Strip swap hitch | 3× width + prefetch; avoid main-thread decode |
| HiDPI blurriness | Bake at backing scale; set `contentsScale` |
| Gesture regression | Port existing hit logic carefully; manual checklist in PR |
| Main-thread `updateNSView` thrash | Diff bake inputs; only reposition on time ticks |

## Success criteria

- During follow-mode playback, detail does **not** re-downsample peaks or refill bars every frame; Instruments shows layer property updates instead.
- Pause path retains seek, marker retiming, scroll pan, pinch zoom, double-click add chapter.
- Visual parity is “close”: CastSnip blue played wash, chapter tints, boundary handles; title pills may remain pause-only or land in a later polish if expensive on CA.

## File sketch (implementation plan will refine)

- `CastSnip/WaveformDetailSurface.swift` — `NSView` + layers + gestures + display link
- `CastSnip/WaveformDetailRepresentable.swift` — SwiftUI bridge (or nested in surface file if small)
- `CastSnip/WaveformStripRenderer` — move/extend bake helpers (from reverted strip work / shared CG drawing)
- `CastSnip/WaveformView.swift` — host representable; delete detail Canvas drawing path when parity reached
- `CastSnipTests` — math coverage for strip/follow

## Open points deferred to planning

- Exact detach/re-attach rules while playing after pan
- Whether region/marker layers are shape layers vs baked images
- Whether title pills appear on CA surface when paused
