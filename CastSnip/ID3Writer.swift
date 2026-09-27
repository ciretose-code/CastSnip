//
//  ID3Writer.swift
//  CastSnip
//
//  Writes ID3v2.3 tags (metadata, artwork, CHAP, CTOC) in front of existing MP3 audio.
//

import Foundation
import AppKit

enum ID3WriterError: Error, LocalizedError {
    case noAudioPayload
    case unreadableSource
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAudioPayload:
            return "The file does not contain MP3 audio data."
        case .unreadableSource:
            return "The original audio file could not be read."
        case .writeFailed(let message):
            return message
        }
    }
}

enum ID3Writer {
    static func mpegAudioPayload(from mp3: Data) -> Data {
        guard mp3.count >= 10, String(data: mp3.prefix(3), encoding: .isoLatin1) == "ID3" else {
            return mp3
        }
        let size = ID3Parser.unsynchsafe(mp3.subdata(in: 6..<10))
        let start = min(10 + size, mp3.count)
        return mp3.subdata(in: start..<mp3.count)
    }

    static func tagData(for podcast: Podcast) -> Data {
        var frames = Data()

        if !podcast.title.isEmpty {
            frames.append(textFrame("TALB", podcast.title))
        }
        if !podcast.episode.isEmpty {
            frames.append(textFrame("TIT2", podcast.episode))
        }
        if !podcast.artist.isEmpty {
            frames.append(textFrame("TPE1", podcast.artist))
        }
        if !podcast.summary.isEmpty {
            frames.append(commentFrame(podcast.summary))
        }
        if let millis = podcast.durationInMillis, millis > 0 {
            frames.append(textFrame("TLEN", String(millis)))
        }
        if let logo = podcast.logo, let jpeg = jpegData(from: logo) {
            frames.append(pictureFrame(jpeg))
        }

        let chapters = podcast.chapters.sorted()
        var visibleElementIDs: [String] = []
        for (index, chapter) in chapters.enumerated() {
            let elementID = "chp\(index)"
            frames.append(chapterFrame(chapter, index: index))
            if !chapter.isHidden {
                visibleElementIDs.append(elementID)
            }
        }
        if !chapters.isEmpty {
            frames.append(tocFrame(elementIDs: visibleElementIDs))
        }

        let padding = Data(repeating: 0, count: 256)
        let size = UInt32(frames.count + padding.count)
        var tag = Data("ID3".utf8)
        tag.append(contentsOf: [0x03, 0x00, 0x00])
        tag.append(contentsOf: ID3Parser.synchsafeBytes(size))
        tag.append(frames)
        tag.append(padding)
        return tag
    }

    static func taggedMP3(from source: Data, podcast: Podcast) -> Data {
        tagData(for: podcast) + mpegAudioPayload(from: source)
    }

    static func write(
        podcast: Podcast,
        from sourceURL: URL,
        to destinationURL: URL,
        includeTags: Bool = true
    ) throws {
        let source: Data
        do {
            source = try Data(contentsOf: sourceURL)
        } catch {
            throw ID3WriterError.unreadableSource
        }

        let audio = mpegAudioPayload(from: source)
        guard !audio.isEmpty else {
            throw ID3WriterError.noAudioPayload
        }

        let output = includeTags ? tagData(for: podcast) + audio : audio
        do {
            try output.write(to: destinationURL, options: .atomic)
        } catch {
            throw ID3WriterError.writeFailed(error.localizedDescription)
        }
    }

    static func jpegData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        else {
            return nil
        }
        return jpeg
    }

    private static func frame(_ identifier: String, body: Data) -> Data {
        var data = Data(identifier.utf8)
        data.append(contentsOf: ID3Parser.uint32Bytes(UInt32(body.count)))
        data.append(contentsOf: [0x00, 0x00])
        data.append(body)
        return data
    }

    private static func textFrame(_ identifier: String, _ text: String) -> Data {
        var body = Data([0x03])
        body.append(contentsOf: text.utf8)
        body.append(0x00)
        return frame(identifier, body: body)
    }

    private static func commentFrame(_ text: String) -> Data {
        var body = Data([0x03])
        body.append(contentsOf: "eng".utf8)
        body.append(0x00)
        body.append(contentsOf: text.utf8)
        body.append(0x00)
        return frame("COMM", body: body)
    }

    private static func pictureFrame(_ jpeg: Data) -> Data {
        var body = Data([0x00])
        body.append(contentsOf: "image/jpeg".utf8)
        body.append(0x00)
        body.append(0x03)
        body.append(0x00)
        body.append(jpeg)
        return frame("APIC", body: body)
    }

    private static func wxxxFrame(_ url: String) -> Data {
        var body = Data([0x00, 0x00])
        body.append(contentsOf: url.utf8)
        body.append(0x00)
        return frame("WXXX", body: body)
    }

    private static func chapterFrame(_ chapter: Chapter, index: Int) -> Data {
        var body = Data()
        body.append(contentsOf: "chp\(index)".utf8)
        body.append(0x00)
        body.append(contentsOf: ID3Parser.uint32Bytes(chapter.startTime))
        body.append(contentsOf: ID3Parser.uint32Bytes(chapter.endTime))
        body.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])

        let title = chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            body.append(textFrame("TIT2", title))
        }
        if !chapter.url.isEmpty {
            body.append(wxxxFrame(chapter.url))
        }
        if let image = chapter.image, let jpeg = jpegData(from: image) {
            body.append(pictureFrame(jpeg))
        }

        return frame("CHAP", body: body)
    }

    private static func tocFrame(elementIDs: [String]) -> Data {
        var body = Data()
        body.append(contentsOf: "toc".utf8)
        body.append(0x00)
        body.append(0x03)
        body.append(UInt8(min(elementIDs.count, 255)))
        for elementID in elementIDs.prefix(255) {
            body.append(contentsOf: elementID.utf8)
            body.append(0x00)
        }
        return frame("CTOC", body: body)
    }
}
