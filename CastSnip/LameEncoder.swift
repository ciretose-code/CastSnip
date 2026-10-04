//
//  LameEncoder.swift
//  CastSnip
//
//  Thin Swift wrapper around the LAME 4.0 C API (SPM product `LAME`
//  from https://github.com/ciretose-code/LAME).
//  LAME remains a dynamic package product (LGPL); this file only configures
//  and drives encode/flush.
//
//  CBR stereo at a chosen bitrate (default 192 kbps). Input sample rate is
//  passed through (44.1 kHz stays 44.1 kHz). Mono sources are duplicated to stereo.
//

import AVFoundation
import Foundation
import LAME

enum LameEncoder {
    enum Error: LocalizedError {
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .failed(let message):
                return message
            }
        }
    }

    static func encode(
        from input: URL,
        to output: URL,
        bitrateKbps: Int = 192,
        progress: ((Double) -> Void)? = nil
    ) throws {
        let audioFile = try AVAudioFile(forReading: input)
        let format = audioFile.processingFormat
        let totalFrames = audioFile.length
        guard totalFrames > 0 else {
            throw Error.failed("Input audio has no frames")
        }
        guard format.sampleRate > 0 else {
            throw Error.failed("Input audio has an invalid sample rate")
        }

        guard let lame = lame_init() else {
            throw Error.failed("lame_init failed")
        }
        defer { lame_close(lame) }

        let bitrate = EncodeBitrate.resolved(bitrateKbps).rawValue
        lame_set_in_samplerate(lame, Int32(format.sampleRate.rounded()))
        lame_set_num_channels(lame, 2)
        lame_set_mode(lame, STEREO)
        lame_set_brate(lame, Int32(bitrate))
        lame_set_VBR(lame, vbr_off)
        guard lame_init_params(lame) >= 0 else {
            throw Error.failed("lame_init_params failed")
        }

        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let handle = try FileHandle(forWritingTo: output)
        defer { try? handle.close() }

        let channelCount = Int(format.channelCount)
        let chunkFrames: AVAudioFrameCount = 4096
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
            throw Error.failed("Could not allocate a PCM buffer")
        }

        progress?(0)
        var framesRead: AVAudioFramePosition = 0

        while audioFile.framePosition < totalFrames {
            try audioFile.read(into: buffer)
            let frameLength = Int(buffer.frameLength)
            if frameLength == 0 { break }

            let bytes = try encodePCM(
                lame: lame,
                buffer: buffer,
                channelCount: channelCount,
                frameLength: frameLength
            )
            if !bytes.isEmpty {
                try handle.write(contentsOf: bytes)
            }

            framesRead += AVAudioFramePosition(frameLength)
            progress?(min(1, Double(framesRead) / Double(totalFrames)))
        }

        let flushed = try flush(lame: lame)
        if !flushed.isEmpty {
            try handle.write(contentsOf: flushed)
        }
        progress?(1)
    }

    private static func encodePCM(
        lame: lame_t,
        buffer: AVAudioPCMBuffer,
        channelCount: Int,
        frameLength: Int
    ) throws -> Data {
        let mp3Capacity = Int(Double(frameLength) * 1.25) + 7200
        var mp3buf = [UInt8](repeating: 0, count: mp3Capacity)
        let encoded: Int32

        if let channels = buffer.floatChannelData {
            let left = channels[0]
            let right = channelCount >= 2 ? channels[1] : channels[0]
            encoded = lame_encode_buffer_ieee_float(
                lame,
                left,
                right,
                Int32(frameLength),
                &mp3buf,
                Int32(mp3Capacity)
            )
        } else if let channels = buffer.int16ChannelData {
            let left = channels[0]
            let right = channelCount >= 2 ? channels[1] : channels[0]
            encoded = lame_encode_buffer(
                lame,
                left,
                right,
                Int32(frameLength),
                &mp3buf,
                Int32(mp3Capacity)
            )
        } else {
            throw Error.failed("Unsupported PCM format for LAME encode")
        }

        guard encoded >= 0 else {
            throw Error.failed("lame encode failed (\(encoded))")
        }
        return Data(mp3buf.prefix(Int(encoded)))
    }

    private static func flush(lame: lame_t) throws -> Data {
        var mp3buf = [UInt8](repeating: 0, count: 7200)
        let flushed = lame_encode_flush(lame, &mp3buf, Int32(mp3buf.count))
        guard flushed >= 0 else {
            throw Error.failed("lame_encode_flush failed (\(flushed))")
        }
        return Data(mp3buf.prefix(Int(flushed)))
    }
}
