//
//  PodcastEncoder.swift
//  CastSnip
//
//  Encode PCM (WAV/AIFF and other AVAudioFile-readable sources) to a podcast file.
//
//  Encode settings via in-process LAME:
//  - MP3: CBR stereo at a chosen bitrate (64 / 96 / 128 / 192 kbps).
//    44.1 kHz is preserved when the source is already 44.1 kHz; LAME will
//    resample if needed.
//  - Fallback: AAC .m4a via AVAssetExportSession (AppleM4A) if LameEncoder
//    throws. Chosen because Core Audio cannot emit MP3 on current macOS.
//

import AVFoundation
import Foundation
import OSLog

enum PodcastEncoder {
    private static let logger = Logger(subsystem: "com.castsnip", category: "PodcastEncoder")

    enum Tool: Equatable {
        case lameInProcess
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

    /// In-process LAME is always preferred once the package product is linked.
    static func preferredTool() -> Tool {
        .lameInProcess
    }

    /// Encodes `input` toward `output`. AAC fallback rewrites the extension to `m4a`.
    /// When `using` is nil, LAME failures fall back to AAC so the app still produces a file.
    /// After a successful MP3 encode, `tagging` is written as ID3v2.3 (show, chapters, art).
    @discardableResult
    static func encode(
        from input: URL,
        to output: URL,
        using tool: Tool? = nil,
        tagging podcast: Podcast? = nil,
        includeTags: Bool = true,
        bitrateKbps: Int = 192,
        encoder: ((URL, URL, ((Double) -> Void)?) throws -> Void)? = nil,
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let resolved = tool ?? preferredTool()
        switch resolved {
        case .lameInProcess:
            do {
                if let encoder {
                    try encoder(input, output, progress)
                } else {
                    try LameEncoder.encode(
                        from: input,
                        to: output,
                        bitrateKbps: bitrateKbps,
                        progress: progress
                    )
                }
                if includeTags, let podcast {
                    try ID3Writer.write(podcast: podcast, from: output, to: output, includeTags: true)
                }
                return output
            } catch {
                if tool != nil { throw error }
                if includeTags {
                    throw error
                }
                logger.error("LAME encode failed (\(error.localizedDescription)); falling back to AAC .m4a")
                return try await encodeAAC(from: input, replacing: output, progress: progress)
            }
        case .aacM4A:
            return try await encodeAAC(from: input, replacing: output, progress: progress)
        }
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

        progress?(0)
        do {
            try await session.export(to: dest, as: .m4a)
        } catch is CancellationError {
            throw EncodeError.failed("AAC export cancelled")
        } catch {
            throw EncodeError.failed(error.localizedDescription)
        }
        progress?(1)
        return dest
    }
}
