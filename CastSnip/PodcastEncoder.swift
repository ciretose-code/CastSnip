//
//  PodcastEncoder.swift
//  CastSnip
//
//  Encode PCM (WAV/AIFF and other AVAudioFile-readable sources) to a podcast file.
//
//  Encode settings (Forecast-class defaults when lame is available):
//  - MP3: 192 kbps CBR stereo (`lame -b 192 -m s --cbr`). 44.1 kHz is preserved
//    when the source is already 44.1 kHz; lame will resample if needed.
//  - Fallback: AAC .m4a via AVAssetExportSession (AppleM4A). Chosen because
//    `afconvert` cannot emit MP3 on current macOS. Documented tradeoff: the
//    user gets a usable podcast file, not a 192 kbps CBR MP3, until lame is
//    installed (`brew install lame`).
//

import AVFoundation
import Foundation
import OSLog

enum PodcastEncoder {
    private static let logger = Logger(subsystem: "com.castsnip", category: "PodcastEncoder")
    static let homebrewLamePath = "/opt/homebrew/bin/lame"

    enum Tool: Equatable {
        case lame(executable: String)
        case aacM4A
    }

    enum EncodeError: LocalizedError {
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .failed(let message):
                return message
            }
        }
    }

    /// Prefers `/opt/homebrew/bin/lame`, then `lame` on PATH. Otherwise AAC .m4a.
    static func preferredTool(
        executableExists: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        resolveOnPATH: (String) -> String? = { which($0) }
    ) -> Tool {
        if executableExists(homebrewLamePath) {
            return .lame(executable: homebrewLamePath)
        }
        if let path = resolveOnPATH("lame"), executableExists(path) {
            return .lame(executable: path)
        }
        return .aacM4A
    }

    static func lameArguments(input: URL, output: URL) -> [String] {
        // -b 192: 192 kbps; -m s: stereo; --cbr: constant bitrate
        ["-b", "192", "-m", "s", "--cbr", input.path, output.path]
    }

    /// Encodes `input` toward `output`. AAC fallback rewrites the extension to `m4a`.
    /// When `using` is nil, lame failures fall back to AAC so a sandboxed app still produces a file.
    @discardableResult
    static func encode(
        from input: URL,
        to output: URL,
        using tool: Tool? = nil,
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let resolved = tool ?? preferredTool()
        switch resolved {
        case .lame(let executable):
            do {
                return try runLame(executable: executable, input: input, output: output, progress: progress)
            } catch {
                if tool != nil { throw error }
                logger.error("lame failed (\(error.localizedDescription)); falling back to AAC .m4a")
                return try await encodeAAC(from: input, replacing: output, progress: progress)
            }
        case .aacM4A:
            return try await encodeAAC(from: input, replacing: output, progress: progress)
        }
    }

    static func which(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let path = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (path?.isEmpty == false) ? path : nil
        } catch {
            return nil
        }
    }

    private static func runLame(
        executable: String,
        input: URL,
        output: URL,
        progress: ((Double) -> Void)?
    ) throws -> URL {
        progress?(0)
        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = lameArguments(input: input, output: output)
        let err = Pipe()
        process.standardError = err
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: output.path) else {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw EncodeError.failed(message?.isEmpty == false ? message! : "lame failed")
        }
        progress?(1)
        return output
    }

    private static func encodeAAC(
        from input: URL,
        replacing output: URL,
        progress: ((Double) -> Void)?
    ) async throws -> URL {
        let dest = output.deletingPathExtension().appendingPathExtension("m4a")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }

        let asset = AVURLAsset(url: input)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw EncodeError.failed("AAC export is not available")
        }
        session.outputURL = dest
        session.outputFileType = .m4a

        progress?(0)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: EncodeError.failed("AAC export cancelled"))
                default:
                    continuation.resume(throwing: session.error ?? EncodeError.failed("AAC export failed"))
                }
            }
        }
        progress?(1)
        return dest
    }
}
