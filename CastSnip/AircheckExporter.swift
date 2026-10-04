//
//  AircheckExporter.swift
//  CastSnip
//
//  Writes one WAV per chapter time range (chapter clips).
//

import AVFoundation
import Foundation

enum AircheckExporter {
    enum ExportError: LocalizedError {
        case emptyRange
        case unreadableSource

        var errorDescription: String? {
            switch self {
            case .emptyRange:
                return "Chapter has no exportable time range."
            case .unreadableSource:
                return "Could not read the source audio file."
            }
        }
    }

    static func chaptersToExport(selected: Chapter?, all: [Chapter]) -> [Chapter] {
        chaptersToExport(selected: selected.map { [$0] } ?? [], all: all)
    }

    static func chaptersToExport(selected: [Chapter], all: [Chapter]) -> [Chapter] {
        if !selected.isEmpty {
            return selected.sorted()
        }
        return all.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func filename(for chapter: Chapter) -> String {
        let trimmed = chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = sanitized(trimmed.isEmpty ? "chapter" : trimmed)
        return "\(base)_\(chapter.startTime).wav"
    }

    static func sanitized(_ title: String) -> String {
        let illegal = CharacterSet(charactersIn: "/:\\?%*|\"<>")
            .union(.newlines)
            .union(.controlCharacters)
        let mapped = title.unicodeScalars.map { illegal.contains($0) ? Character("-") : Character($0) }
        let cleaned = String(mapped).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "chapter" : cleaned
    }

    @discardableResult
    static func export(from source: URL, chapters: [Chapter], to directory: URL) async throws -> [URL] {
        var urls: [URL] = []
        for chapter in chapters {
            urls.append(try exportChapter(from: source, chapter: chapter, to: directory))
        }
        return urls
    }

    private static func exportChapter(from source: URL, chapter: Chapter, to directory: URL) throws -> URL {
        let file = try AVAudioFile(forReading: source)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        guard sampleRate > 0, file.length > 0 else {
            throw ExportError.unreadableSource
        }

        let startFrame = max(0, AVAudioFramePosition((Double(chapter.startTime) / 1000.0) * sampleRate))
        let endMillis: UInt32
        if chapter.endTime == 0 {
            endMillis = UInt32((Double(file.length) / sampleRate) * 1000.0)
        } else {
            endMillis = chapter.endTime
        }
        let endFrame = min(file.length, AVAudioFramePosition((Double(endMillis) / 1000.0) * sampleRate))
        guard endFrame > startFrame else {
            throw ExportError.emptyRange
        }

        let dest = directory.appendingPathComponent(filename(for: chapter))
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }

        let out = try AVAudioFile(forWriting: dest, settings: format.settings)
        file.framePosition = startFrame
        var remaining = AVAudioFrameCount(endFrame - startFrame)
        let chunk: AVAudioFrameCount = 8192
        while remaining > 0 {
            let count = min(chunk, remaining)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else {
                throw ExportError.unreadableSource
            }
            try file.read(into: buffer, frameCount: count)
            guard buffer.frameLength > 0 else { break }
            try out.write(from: buffer)
            remaining -= buffer.frameLength
        }
        return dest
    }
}
