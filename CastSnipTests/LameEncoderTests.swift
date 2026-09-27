import Testing
import Foundation
import LAME
@testable import CastSnip

struct LameEncoderTests {

    /// Fails while CastSnip still links BB9z 3.100.x; passes on LAME 4.x.
    @Test func linkedLibraryIsLAME4() {
        let version = String(cString: get_lame_version())
        #expect(version.hasPrefix("4."), "expected LAME 4.x, got \(version)")
    }

    @Test func encodesSyntheticWAVToMPEGLayerIII() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-lame-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("tone.wav")
        try ProductionAudioFixtures.writeSineWAV(to: input, duration: 0.4)
        let output = directory.appendingPathComponent("tone.mp3")

        try LameEncoder.encode(from: input, to: output)

        #expect(FileManager.default.fileExists(atPath: output.path))
        let data = try Data(contentsOf: output)
        #expect(data.count > 128)
        #expect(isMPEGAudio(data))
    }

    @Test func reportsProgressFromZeroToOne() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-lame-progress-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("tone.wav")
        try ProductionAudioFixtures.writeSineWAV(to: input, duration: 0.4)
        let output = directory.appendingPathComponent("tone.mp3")

        var progressValues: [Double] = []
        try LameEncoder.encode(from: input, to: output) { progressValues.append($0) }

        #expect(progressValues.contains { $0 == 0 || $0 > 0 })
        #expect(progressValues.contains { $0 >= 1 })
        #expect(progressValues.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    @Test func throwsAClearErrorWhenInputCannotBeRead() {
        let missing = URL(fileURLWithPath: "/tmp/castsnip-missing-\(UUID().uuidString).wav")
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-lame-fail-\(UUID().uuidString).mp3")

        #expect(throws: (any Error).self) {
            try LameEncoder.encode(from: missing, to: output)
        }
    }

    private func isMPEGAudio(_ data: Data) -> Bool {
        guard data.count >= 3 else { return false }
        if data.starts(with: [0x49, 0x44, 0x33]) { return true }
        if data[0] == 0xFF && (data[1] == 0xFB || data[1] == 0xF3) { return true }
        return false
    }
}
