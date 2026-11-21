import Testing
import CoreGraphics
@testable import CastSnip

struct WaveformStripBakerTests {
    @Test func bakeProducesImageAtScaledPixelSize() {
        let input = WaveformStripBaker.Input(
            size: CGSize(width: 300, height: 100),
            scale: 2,
            stripStart: 0,
            stripDuration: 30,
            audioDuration: 60,
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

    @Test func amplitudeBarAtDetailHeightUsesMostOfStrip() {
        let height: CGFloat = 56
        let rect = WaveformStripBaker.amplitudeBarRect(
            sample: 1,
            x: 0,
            barWidth: 2,
            height: height
        )
        #expect(rect.height >= height * 0.75)
        #expect(abs(rect.midY - height / 2) < 0.5)
        #expect(rect.minY >= 0)
        #expect(rect.maxY <= height)
    }
}
