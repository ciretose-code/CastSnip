# Play waveform: fixed window, walking playhead

**Date:** 2026-11-20  
**Status:** approved  
**Size:** small change

## Intent

The zoomed “play” waveform is for fine-tuning chapter breaks, not for watching playback. Today it fills the timeline pane and continuously recenters on the playhead while playing, which feels large and jumpy. The full-audio overview already handles “where am I.” Make the zoom strip short and calm: a fixed window with a walking playhead.

## Goals

- Cap the zoom strip to a short fixed height (~56pt), quieter than today.
- While playing, keep `viewportStart` fixed so the strip does not scroll every frame.
- Draw the playhead moving across that fixed window (and the played wash).
- When the playhead leaves the window, page the window forward/back (unless the user has detached by panning).
- Keep full-audio overview behavior and look as they are.
- Keep chapter-edge drag, seek, pan, pinch-zoom, overview jump.

## Non-goals

- Redesigning the overview strip.
- Marker-rail-only UI (option C) or hide-while-playing (option D).
- Changing chapter list / transport / inspector.

## Anti-goals

- Continuous center-follow while playing (today’s behavior) — that is the jumpiness.
- Leaving the zoom strip as a flexible `maxHeight: .infinity` fill.

## Approaches considered

| Option | Idea | Tradeoff |
|--------|------|----------|
| A Slim zoom | Short height, same follow | Still scrolls while playing |
| **B Fixed window + walking playhead** | Short height; window stays put; playhead walks; page at edge | Less “live feel,” clearer for editing |
| C Marker rail | Handles only, amplitude on overview | Harder to spot silence in zoom |
| D Play quiet / edit loud | Hide zoom while playing | Zero motion, but no zoom context while listening |

**Chosen:** B (Eric, 2026-11-20).

## Design

### Layout

```
[ chapter title bar ]
[ zoom strip ~56pt ]   ← fixed height, not flexible fill
[ time ruler ~20pt ]
[ full audio ~32pt ]   ← unchanged
[ transport ]
```

Zoom strip height: **56pt** (builder call; adjust if it feels wrong in app).

### Playback / viewport

- **Paused / snap / overview seek / start of play:** existing snap-to-playhead centering is fine (one-shot).
- **While playing and not detached:** do **not** call continuous center-follow. Leave `viewportStart` alone. Playhead x moves within the strip via existing `playheadX` math.
- **Page when leaving the window:** if `currentTime` exits `[viewportStart, viewportStart + viewportDuration]`:
  - Exited right → set `viewportStart` so playhead sits ~10% from the left of the new window.
  - Exited left → set `viewportStart` so playhead sits ~10% from the right.
  - Clamp with existing `ViewportMath.clampViewportStart`.
- **Detached (user pan while playing):** keep today’s rule — do not auto-page until snap / overview seek / play-from-stopped resets detach.
- **WaveformDetailSurface `followsPlayhead`:** stop scrolling/rebaking the strip every frame to keep the playhead centered. Chrome (playhead, wash, markers) still updates live; strip bake keys off viewport window, not continuous follow-anchor.

### Visual quieting (minor)

- Prefer the strip reading as a tool under the title bar, not a hero — muted amplitude vs today’s full-bleed fill is enough; no new chrome.

### Touch points (expected)

- `ViewportMath.followedStart` (or successor): center-follow → page-on-exit while playing.
- `ContentView.updateViewport` / detach / snap wiring.
- `WaveformView` detail `.frame(height:)` instead of `maxHeight: .infinity`.
- `WaveformDetailSurface` follow/scroll path: no continuous strip offset-follow while playing.

### Left to the builder

- Exact page inset (10% vs a fixed seconds margin).
- Whether displayLink still runs only for chrome while playing (yes if needed for smooth playhead).
- Tests for page-on-exit and “no move while playhead inside window.”

## Approval

Approve this design to proceed to an implementation plan.
