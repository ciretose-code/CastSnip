//
//  WaveformStripBaker.swift
//  CastSnip
//
//  Offscreen CG bake of a waveform strip (regions + bars + marker lines) for CALayer.contents.
//

import AppKit
import CoreGraphics
import Foundation

enum WaveformStripBaker {
    struct MarkerDTO: Sendable {
        var time: TimeInterval
        var end: TimeInterval?
        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat
        var alpha: CGFloat
        var isSelected: Bool
        var isLocked: Bool
        var lineWidth: CGFloat
    }

    struct Input: Sendable {
        var size: CGSize
        var scale: CGFloat
        var stripStart: TimeInterval
        var stripDuration: TimeInterval
        var audioDuration: TimeInterval
        var overview: [Float]
        var overviewBucketDuration: TimeInterval
        var tiles: [Int: [Float]]
        var markers: [MarkerDTO]
    }

    nonisolated static func bake(_ input: Input) -> CGImage? {
        let scale = max(input.scale, 1)
        let pixelWidth = max(1, Int((input.size.width * scale).rounded()))
        let pixelHeight = max(1, Int((input.size.height * scale).rounded()))
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
            return nil
        }

        ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
        ctx.scaleBy(x: scale, y: -scale)

        let width = input.size.width
        let height = input.size.height
        let stripStart = input.stripStart
        let stripDuration = input.stripDuration
        let audioDuration = input.audioDuration

        for marker in input.markers {
            let end = marker.end ?? audioDuration
            guard end > stripStart, marker.time < stripStart + stripDuration else { continue }
            let x0 = xPosition(time: marker.time, stripStart: stripStart, stripDuration: stripDuration, width: width)
            let x1 = xPosition(time: end, stripStart: stripStart, stripDuration: stripDuration, width: width)
            let rect = CGRect(x: x0, y: 0, width: max(x1 - x0, 0), height: height)
            let opacity: CGFloat = marker.isSelected ? 0.24 : 0.10
            ctx.setFillColor(CGColor(
                red: marker.red,
                green: marker.green,
                blue: marker.blue,
                alpha: marker.alpha * opacity
            ))
            ctx.fill(rect)
        }

        let visibleBuckets: [Float]
        if stripDuration <= WaveformPeakStore.maxDetailWindow {
            visibleBuckets = WaveformSampling.viewportPeaks(
                overview: input.overview,
                overviewBucketDuration: input.overviewBucketDuration,
                tiles: input.tiles,
                tileDuration: WaveformPeakStore.tileDuration,
                detailBucketDuration: WaveformPeakStore.detailBucketDuration,
                start: stripStart,
                end: stripStart + stripDuration
            )
        } else {
            visibleBuckets = WaveformSampling.samplesForViewport(
                samples: input.overview,
                audioDuration: audioDuration,
                viewportStart: stripStart,
                viewportDuration: stripDuration,
                bucketDuration: input.overviewBucketDuration
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

        for marker in input.markers {
            guard marker.time >= stripStart - 0.0001,
                  marker.time <= stripStart + stripDuration + 0.0001 else { continue }
            let x = xPosition(time: marker.time, stripStart: stripStart, stripDuration: stripDuration, width: width)
            let lineWidth: CGFloat = marker.isSelected ? 3 : marker.lineWidth
            ctx.setStrokeColor(CGColor(
                red: marker.red,
                green: marker.green,
                blue: marker.blue,
                alpha: marker.alpha
            ))
            ctx.setLineWidth(lineWidth)
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: height))
            ctx.strokePath()

            guard !marker.isLocked else { continue }
            let handle = CGRect(x: x - 4, y: height - 18, width: 8, height: 16)
            ctx.setFillColor(CGColor(
                red: marker.red,
                green: marker.green,
                blue: marker.blue,
                alpha: marker.alpha
            ))
            ctx.fill(handle)
        }

        return ctx.makeImage()
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
}
