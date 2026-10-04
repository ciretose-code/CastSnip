//
//  WaveformStripCache.swift
//  CastSnip
//
//  Pre-renders a wide waveform strip for playback: the playhead stays fixed and the
//  image slides underneath. Live Canvas rendering resumes when playback stops.
//

import AppKit
import CoreGraphics
import Foundation
import Observation
import SwiftUI

struct WaveformStripSnapshot {
    let image: NSImage
    let start: TimeInterval
    let duration: TimeInterval
    let pixelWidth: CGFloat
    let viewWidth: CGFloat
    let viewHeight: CGFloat
}

@MainActor
@Observable
final class WaveformStripCache {
    private(set) var snapshot: WaveformStripSnapshot?
    private var generation = 0

    func invalidate() {
        generation += 1
        snapshot = nil
    }

    /// Ensures a strip covering `currentTime` is ready. Re-renders when missing, the
    /// view size changes, or the playhead nears the strip edge.
    func ensureStrip(
        currentTime: TimeInterval,
        viewportDuration: TimeInterval,
        audioDuration: TimeInterval,
        viewWidth: CGFloat,
        viewHeight: CGFloat,
        scale: CGFloat,
        overview: [Float],
        overviewBucketDuration: TimeInterval,
        tiles: [Int: [Float]],
        markers: [WaveformView.Marker]
    ) async {
        guard viewWidth > 1, viewHeight > 1, audioDuration > 0, viewportDuration > 0 else { return }

        if let snapshot,
           abs(snapshot.viewWidth - viewWidth) < 0.5,
           abs(snapshot.viewHeight - viewHeight) < 0.5,
           !WaveformStripMath.needsPrefetch(
               currentTime: currentTime,
               stripStart: snapshot.start,
               stripDuration: snapshot.duration
           ) {
            return
        }

        generation += 1
        let token = generation
        let window = WaveformStripMath.stripWindow(
            anchorTime: currentTime,
            viewportDuration: viewportDuration,
            audioDuration: audioDuration
        )
        guard window.duration > 0 else { return }

        let stripPixelWidth = viewWidth * CGFloat(WaveformStripMath.widthInViewports)
        let size = CGSize(width: stripPixelWidth, height: viewHeight)
        let renderScale = max(scale, 1)

        let overviewCopy = overview
        let tilesCopy = tiles
        let markersCopy = markers
        let overviewBucket = overviewBucketDuration

        let image = await Task.detached(priority: .userInitiated) {
            WaveformStripRenderer.render(
                size: size,
                scale: renderScale,
                stripStart: window.start,
                stripDuration: window.duration,
                audioDuration: audioDuration,
                overview: overviewCopy,
                overviewBucketDuration: overviewBucket,
                tiles: tilesCopy,
                markers: markersCopy
            )
        }.value

        guard token == generation else { return }
        snapshot = WaveformStripSnapshot(
            image: image,
            start: window.start,
            duration: window.duration,
            pixelWidth: stripPixelWidth,
            viewWidth: viewWidth,
            viewHeight: viewHeight
        )
    }
}

enum WaveformStripRenderer {
    /// Offscreen waveform strip: chapter tints, bars, and boundary lines (no title pills).
    nonisolated static func render(
        size: CGSize,
        scale: CGFloat,
        stripStart: TimeInterval,
        stripDuration: TimeInterval,
        audioDuration: TimeInterval,
        overview: [Float],
        overviewBucketDuration: TimeInterval,
        tiles: [Int: [Float]],
        markers: [WaveformView.Marker]
    ) -> NSImage {
        let pixelWidth = max(1, Int((size.width * scale).rounded()))
        let pixelHeight = max(1, Int((size.height * scale).rounded()))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return NSImage(size: size)
        }

        // Flip to top-left origin matching SwiftUI Canvas.
        ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
        ctx.scaleBy(x: scale, y: -scale)

        let width = size.width
        let height = size.height

        for marker in markers {
            let end = marker.end ?? audioDuration
            guard end > stripStart, marker.time < stripStart + stripDuration else { continue }
            let x0 = xPosition(time: marker.time, stripStart: stripStart, stripDuration: stripDuration, width: width)
            let x1 = xPosition(time: end, stripStart: stripStart, stripDuration: stripDuration, width: width)
            let rect = CGRect(x: x0, y: 0, width: max(x1 - x0, 0), height: height)
            let opacity: CGFloat = marker.isSelected ? 0.24 : 0.10
            ctx.setFillColor(nsColor(marker.color).withAlphaComponent(opacity).cgColor)
            ctx.fill(rect)
        }

        let visibleBuckets: [Float]
        if stripDuration <= WaveformPeakStore.maxDetailWindow {
            visibleBuckets = WaveformSampling.viewportPeaks(
                overview: overview,
                overviewBucketDuration: overviewBucketDuration,
                tiles: tiles,
                tileDuration: WaveformPeakStore.tileDuration,
                detailBucketDuration: WaveformPeakStore.detailBucketDuration,
                start: stripStart,
                end: stripStart + stripDuration
            )
        } else {
            visibleBuckets = WaveformSampling.samplesForViewport(
                samples: overview,
                audioDuration: audioDuration,
                viewportStart: stripStart,
                viewportDuration: stripDuration,
                bucketDuration: overviewBucketDuration
            )
        }

        if !visibleBuckets.isEmpty {
            let targetBarCount = max(1, Int(floor(width)))
            let bars = WaveformSampling.downsample(buckets: visibleBuckets, maxBars: targetBarCount)
            let barWidth = width / CGFloat(bars.count)
            let midHeight = height / 2
            ctx.setFillColor(NSColor.labelColor.withAlphaComponent(0.55).cgColor)

            for (index, sample) in bars.enumerated() {
                let x = CGFloat(index) * barWidth
                let barHeight = CGFloat(sample) * (height - 36) * 0.9
                let rect = CGRect(
                    x: x,
                    y: midHeight + 8 - barHeight / 2,
                    width: max(barWidth - 0.5, 1),
                    height: max(barHeight, 1)
                )
                ctx.fill(rect)
            }
        }

        for marker in markers {
            guard marker.time >= stripStart - 0.0001, marker.time <= stripStart + stripDuration + 0.0001 else { continue }
            let x = xPosition(time: marker.time, stripStart: stripStart, stripDuration: stripDuration, width: width)
            let lineWidth: CGFloat = marker.isSelected ? 3 : marker.lineWidth
            ctx.setStrokeColor(nsColor(marker.color).cgColor)
            ctx.setLineWidth(lineWidth)
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: height))
            ctx.strokePath()

            guard !marker.isLocked else { continue }
            let handle = CGRect(x: x - 4, y: height - 18, width: 8, height: 16)
            ctx.setFillColor(nsColor(marker.color).cgColor)
            ctx.fill(handle)
        }

        guard let cgImage = ctx.makeImage() else {
            return NSImage(size: size)
        }
        return NSImage(cgImage: cgImage, size: size)
    }

    nonisolated private static func xPosition(
        time: TimeInterval,
        stripStart: TimeInterval,
        stripDuration: TimeInterval,
        width: CGFloat
    ) -> CGFloat {
        guard stripDuration > 0 else { return 0 }
        return CGFloat((time - stripStart) / stripDuration) * width
    }

    nonisolated private static func nsColor(_ color: Color) -> NSColor {
        NSColor(color)
    }
}
