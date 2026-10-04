//
//  WaveformDetailSurface.swift
//  CastSnip
//
//  AppKit + Core Animation detail waveform: bake a wide strip once, scroll layers
//  while playing, live playhead / played wash overlays.
//

import AppKit
import QuartzCore
import SwiftUI

struct WaveformDetailModel: Equatable {
    var viewportStart: TimeInterval
    var viewportDuration: TimeInterval
    var currentTime: TimeInterval
    var isPlaying: Bool
    var audioDuration: TimeInterval
    var overview: [Float]
    var overviewBucketDuration: TimeInterval
    var tiles: [Int: [Float]]
    var markers: [WaveformView.Marker]
    var followEpoch: Int

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.viewportStart == rhs.viewportStart
            && lhs.viewportDuration == rhs.viewportDuration
            && lhs.currentTime == rhs.currentTime
            && lhs.isPlaying == rhs.isPlaying
            && lhs.audioDuration == rhs.audioDuration
            && lhs.overviewBucketDuration == rhs.overviewBucketDuration
            && lhs.overview == rhs.overview
            && lhs.tiles.keys.sorted() == rhs.tiles.keys.sorted()
            && lhs.tiles.allSatisfy { rhs.tiles[$0.key] == $0.value }
            && lhs.markers == rhs.markers
            && lhs.followEpoch == rhs.followEpoch
    }
}

struct WaveformDetailRepresentable: NSViewRepresentable {
    var model: WaveformDetailModel
    var onSeek: (TimeInterval) -> Void
    var onViewportPan: (TimeInterval) -> Void
    var onMarkerMove: (UUID, TimeInterval) -> Void
    var onMarkerMoveEnded: (UUID) -> Void
    var onAddChapter: (TimeInterval) -> Void
    var onZoom: (Bool) -> Void

    func makeNSView(context: Context) -> WaveformDetailSurface {
        let view = WaveformDetailSurface()
        view.onSeek = onSeek
        view.onViewportPan = onViewportPan
        view.onMarkerMove = onMarkerMove
        view.onMarkerMoveEnded = onMarkerMoveEnded
        view.onAddChapter = onAddChapter
        view.onZoom = onZoom
        view.applyModel(model)
        return view
    }

    func updateNSView(_ nsView: WaveformDetailSurface, context: Context) {
        nsView.onSeek = onSeek
        nsView.onViewportPan = onViewportPan
        nsView.onMarkerMove = onMarkerMove
        nsView.onMarkerMoveEnded = onMarkerMoveEnded
        nsView.onAddChapter = onAddChapter
        nsView.onZoom = onZoom
        nsView.applyModel(model)
    }
}

final class WaveformDetailSurface: NSView {
    var onSeek: ((TimeInterval) -> Void)?
    var onViewportPan: ((TimeInterval) -> Void)?
    var onMarkerMove: ((UUID, TimeInterval) -> Void)?
    var onMarkerMoveEnded: ((UUID) -> Void)?
    var onAddChapter: ((TimeInterval) -> Void)?
    var onZoom: ((Bool) -> Void)?

    private let contentLayer = CALayer()
    private let waveformLayer = CALayer()
    private let playedWashLayer = CALayer()
    private let playheadLayer = CAShapeLayer()

    private var model = WaveformDetailModel(
        viewportStart: 0,
        viewportDuration: 10,
        currentTime: 0,
        isPlaying: false,
        audioDuration: 0,
        overview: [],
        overviewBucketDuration: 0,
        tiles: [:],
        markers: [],
        followEpoch: 0
    )

    private var stripStart: TimeInterval = 0
    private var stripDuration: TimeInterval = 0
    private var stripPixelWidth: CGFloat = 0
    private var bakeGeneration = 0
    private var lastBakeKey: BakeKey?
    private var displayLink: CADisplayLink?
    private let displayLinkTarget = DisplayLinkProxy()

    private var dragMarkerID: UUID?
    private var dragModeDecided = false
    private let markerGrabDistance: CGFloat = 6
    private var magnifyGesture: NSMagnificationGestureRecognizer?

    private struct BakeKey: Equatable {
        var stripStart: TimeInterval
        var stripDuration: TimeInterval
        var viewWidth: CGFloat
        var viewHeight: CGFloat
        var scale: CGFloat
        var overviewCount: Int
        var tileKeys: [Int]
        var markerIDs: [UUID]
        var selectedID: UUID?
        var audioDuration: TimeInterval
        var viewportDuration: TimeInterval
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor

        contentLayer.masksToBounds = false
        waveformLayer.contentsGravity = .resize
        playedWashLayer.backgroundColor = NSColor(Color.castSnipBlue).withAlphaComponent(0.28).cgColor
        playheadLayer.fillColor = NSColor.white.withAlphaComponent(0.9).cgColor
        playheadLayer.strokeColor = NSColor.black.withAlphaComponent(0.35).cgColor
        playheadLayer.lineWidth = 1.5

        layer?.addSublayer(contentLayer)
        contentLayer.addSublayer(waveformLayer)
        layer?.addSublayer(playedWashLayer)
        layer?.addSublayer(playheadLayer)

        let magnify = NSMagnificationGestureRecognizer(target: self, action: #selector(handleMagnify(_:)))
        addGestureRecognizer(magnify)
        magnifyGesture = magnify

        displayLinkTarget.handler = { [weak self] in
            self?.displayLinkFired()
        }
    }

    deinit {
        stopDisplayLink()
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        contentLayer.contentsScale = scale
        waveformLayer.contentsScale = scale
        playedWashLayer.contentsScale = scale
        playheadLayer.contentsScale = scale
        requestBakeIfNeeded(force: false)
        updateChrome()
    }

    func applyModel(_ newModel: WaveformDetailModel) {
        let playingChanged = newModel.isPlaying != model.isPlaying
        let epochChanged = newModel.followEpoch != model.followEpoch
        model = newModel
        if playingChanged {
            if model.isPlaying {
                startDisplayLink()
            } else {
                stopDisplayLink()
            }
        }
        if epochChanged, model.isPlaying {
            // Overview seek / snap: ensure strip recenters on playhead.
            requestBakeIfNeeded(force: true)
        } else {
            requestBakeIfNeeded(force: false)
        }
        updateChrome()
    }

    // MARK: - Bake

    private func requestBakeIfNeeded(force: Bool) {
        let bounds = self.bounds
        guard bounds.width > 1, bounds.height > 1, model.audioDuration > 0, model.viewportDuration > 0 else { return }
        guard !model.overview.isEmpty else { return }

        // While playing, keep scrolling the existing strip until the playhead nears an edge.
        if model.isPlaying, !force, waveformLayer.contents != nil, stripDuration > 0 {
            let needsPrefetch = WaveformStripMath.needsPrefetch(
                currentTime: model.currentTime,
                stripStart: stripStart,
                stripDuration: stripDuration
            )
            if !needsPrefetch { return }
        }

        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let anchor: TimeInterval = model.isPlaying
            ? model.currentTime
            : model.viewportStart + model.viewportDuration / 2
        let stripWindow = WaveformStripMath.stripWindow(
            anchorTime: anchor,
            viewportDuration: model.viewportDuration,
            audioDuration: model.audioDuration
        )
        let key = BakeKey(
            stripStart: stripWindow.start,
            stripDuration: stripWindow.duration,
            viewWidth: bounds.width,
            viewHeight: bounds.height,
            scale: scale,
            overviewCount: model.overview.count,
            tileKeys: model.tiles.keys.sorted(),
            markerIDs: model.markers.map(\.id),
            selectedID: model.markers.first(where: \.isSelected)?.id,
            audioDuration: model.audioDuration,
            viewportDuration: model.viewportDuration
        )
        guard force || lastBakeKey != key else { return }

        lastBakeKey = key
        bakeGeneration += 1
        let token = bakeGeneration
        let stripPixelWidth = bounds.width * CGFloat(WaveformStripMath.widthInViewports)
        let size = CGSize(width: stripPixelWidth, height: bounds.height)
        let markers = Self.markerDTOs(from: model.markers)
        let input = WaveformStripBaker.Input(
            size: size,
            scale: scale,
            stripStart: stripWindow.start,
            stripDuration: stripWindow.duration,
            audioDuration: model.audioDuration,
            overview: model.overview,
            overviewBucketDuration: model.overviewBucketDuration,
            tiles: model.tiles,
            markers: markers
        )

        let stripStart = stripWindow.start
        let stripDuration = stripWindow.duration
        let height = bounds.height
        Task.detached(priority: .userInitiated) {
            let image = WaveformStripBaker.bake(input)
            await MainActor.run { [weak self] in
                self?.finishBake(
                    image: image,
                    token: token,
                    stripStart: stripStart,
                    stripDuration: stripDuration,
                    stripPixelWidth: stripPixelWidth,
                    height: height
                )
            }
        }
    }

    private func finishBake(
        image: CGImage?,
        token: Int,
        stripStart: TimeInterval,
        stripDuration: TimeInterval,
        stripPixelWidth: CGFloat,
        height: CGFloat
    ) {
        guard token == bakeGeneration, let image else { return }
        self.stripStart = stripStart
        self.stripDuration = stripDuration
        self.stripPixelWidth = stripPixelWidth
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        waveformLayer.contents = image
        waveformLayer.frame = CGRect(x: 0, y: 0, width: stripPixelWidth, height: height)
        contentLayer.frame = bounds
        CATransaction.commit()
        updateChrome()
    }

    private static func markerDTOs(from markers: [WaveformView.Marker]) -> [WaveformStripBaker.MarkerDTO] {
        markers.map { marker in
            let ns = NSColor(marker.color)
            let rgb = ns.usingColorSpace(.deviceRGB) ?? ns
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
            return WaveformStripBaker.MarkerDTO(
                time: marker.time,
                end: marker.end,
                red: r,
                green: g,
                blue: b,
                alpha: a,
                isSelected: marker.isSelected,
                isLocked: marker.isLocked,
                lineWidth: marker.lineWidth
            )
        }
    }

    // MARK: - Chrome (offset, wash, playhead)

    private func updateChrome() {
        let width = bounds.width
        let height = bounds.height
        guard width > 1, height > 1, stripDuration > 0, stripPixelWidth > 0 else { return }

        // Same window as the SwiftUI ruler: clamped `viewportStart`, not hard-centered playhead.
        let offset = WaveformStripMath.imageOffsetX(
            visibleStart: model.viewportStart,
            stripStart: stripStart,
            stripDuration: stripDuration,
            stripPixelWidth: stripPixelWidth
        )

        let playheadX: CGFloat
        if let x = ViewportMath.playheadX(
            time: model.currentTime,
            viewportStart: model.viewportStart,
            viewportDuration: model.viewportDuration,
            audioDuration: model.audioDuration,
            width: Double(width)
        ) {
            playheadX = CGFloat(x)
        } else {
            playheadX = -10
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentLayer.frame = bounds
        waveformLayer.frame = CGRect(x: offset, y: 0, width: stripPixelWidth, height: height)
        playedWashLayer.frame = CGRect(x: 0, y: 0, width: max(playheadX, 0), height: height)
        updatePlayheadPath(at: playheadX, height: height)
        CATransaction.commit()
    }

    private func updatePlayheadPath(at x: CGFloat, height: CGFloat) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: height))
        // Cap
        path.move(to: CGPoint(x: x - 5, y: 0))
        path.addLine(to: CGPoint(x: x + 5, y: 0))
        path.addLine(to: CGPoint(x: x, y: 7))
        path.closeSubpath()
        playheadLayer.path = path
        playheadLayer.frame = bounds
    }

    // MARK: - Display link

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = displayLink(target: displayLinkTarget, selector: #selector(DisplayLinkProxy.fire(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func displayLinkFired() {
        guard model.isPlaying else { return }
        // Time is pushed from SwiftUI; chrome only. Prefetch checked on apply/layout.
        if WaveformStripMath.needsPrefetch(
            currentTime: model.currentTime,
            stripStart: stripStart,
            stripDuration: stripDuration
        ) {
            requestBakeIfNeeded(force: false)
        }
        updateChrome()
    }

    // MARK: - Hit testing / gestures

    private func time(atX x: CGFloat) -> TimeInterval? {
        ViewportMath.seekTime(
            x: Double(x),
            width: Double(bounds.width),
            viewportStart: model.viewportStart,
            viewportDuration: model.viewportDuration,
            audioDuration: model.audioDuration
        )
    }

    private func marker(nearX x: CGFloat) -> WaveformView.Marker? {
        let width = bounds.width
        guard width > 0, model.viewportDuration > 0 else { return nil }
        let windowStart = model.viewportStart
        let windowDuration = model.viewportDuration
        return model.markers
            .filter { !$0.isLocked && $0.time >= windowStart && $0.time <= windowStart + windowDuration }
            .map { marker -> (WaveformView.Marker, CGFloat) in
                let mx = CGFloat((marker.time - windowStart) / windowDuration) * width
                return (marker, abs(mx - x))
            }
            .filter { $0.1 <= markerGrabDistance }
            .min(by: { $0.1 < $1.1 })?
            .0
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        dragModeDecided = false
        dragMarkerID = nil

        if event.clickCount >= 2 {
            if let t = time(atX: loc.x) {
                onAddChapter?(t)
            }
            return
        }

        if let marker = marker(nearX: loc.x) {
            dragModeDecided = true
            dragMarkerID = marker.id
        } else if let t = time(atX: loc.x) {
            onSeek?(t)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if !dragModeDecided {
            dragModeDecided = true
            dragMarkerID = marker(nearX: loc.x)?.id
        }
        guard let t = time(atX: loc.x) else { return }
        if let id = dragMarkerID {
            onMarkerMove?(id, t)
        } else {
            onSeek?(t)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if let id = dragMarkerID {
            onMarkerMoveEnded?(id)
            requestBakeIfNeeded(force: true)
        }
        dragMarkerID = nil
        dragModeDecided = false
    }

    override func scrollWheel(with event: NSEvent) {
        guard let delta = ViewportMath.panDeltaSeconds(
            deltaX: Double(event.scrollingDeltaX),
            width: Double(bounds.width),
            viewportDuration: model.viewportDuration
        ) else { return }
        onViewportPan?(delta)
    }

    override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if marker(nearX: loc.x) != nil {
            NSCursor.resizeLeftRight.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    @objc private func handleMagnify(_ gesture: NSMagnificationGestureRecognizer) {
        guard gesture.state == .ended else { return }
        onZoom?(gesture.magnification > 0)
    }
}

private final class DisplayLinkProxy: NSObject {
    var handler: (() -> Void)?

    @objc func fire(_ link: CADisplayLink) {
        handler?()
    }
}
