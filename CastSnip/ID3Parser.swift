//
//  ID3Parser.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/28/24.
//

import Foundation

struct ID3TagHeader {
    var name: String = ""
    var length: UInt32 = 0
    var flags: UInt16 = 0
}

enum ID3StringEncoding {
    case ASCII
    case UCS2
    case UTF16BE
    case UTF8
}

enum ID3ParserError: Error, LocalizedError {
    case missingTag
    case unsupportedVersion(UInt8)

    var errorDescription: String? {
        switch self {
        case .missingTag:
            return "The file does not contain an ID3 tag."
        case .unsupportedVersion(let version):
            return "ID3v2.\(version) is not supported. CastSnip reads ID3v2.3 tags."
        }
    }
}

class ID3Parser {

    static func uint32Bytes(_ value: UInt32) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }

    static func synchsafeBytes(_ value: UInt32) -> [UInt8] {
        [
            UInt8((value >> 21) & 0x7F),
            UInt8((value >> 14) & 0x7F),
            UInt8((value >> 7) & 0x7F),
            UInt8(value & 0x7F)
        ]
    }

    static func unsynchsafe(_ data: Data) -> Int {
        guard data.count >= 4 else { return 0 }
        let bytes = [UInt8](data.prefix(4))
        return (Int(bytes[0]) << 21) | (Int(bytes[1]) << 14) | (Int(bytes[2]) << 7) | Int(bytes[3])
    }

    static func getTagHeader(_ data: Data, _ offset: inout Int) -> ID3TagHeader {
        guard offset >= 0, offset + 10 <= data.count else {
            return ID3TagHeader()
        }
        let end = offset + 4
        let name = String(decoding: data[offset..<end], as: UTF8.self)
        offset = end
        let length = getUInt32(data, &offset)
        let flags = getUInt16(data, &offset)
        return ID3TagHeader(name: name, length: length, flags: flags)
    }
    
    static func getUInt8(_ data: Data, _ offset: inout Int) -> UInt8 {
        guard offset >= 0, offset + 1 <= data.count else { return 0 }
        let value = data[offset]
        offset += 1
        return value
    }
    
    static func getUInt16(_ data: Data, _ offset: inout Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else { return 0 }
        let value = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        offset += 2
        return value
    }
    
    static func getUInt32(_ data: Data, _ offset: inout Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { return 0 }
        let value = UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
        offset += 4
        return value
    }
    
    static func decodeData(_ data: Data, _ encoding: ID3StringEncoding) -> String {
        switch encoding {
        case .ASCII:
            return String(data: data, encoding: .ascii) ?? ""
        case .UCS2:
            return String(data: data, encoding: .utf16) ?? ""
        case .UTF16BE:
            return String(data: data, encoding: .utf16BigEndian) ?? ""
        case .UTF8:
            return String(data: data, encoding: .utf8) ?? ""
        }
    }
    
    static func getData(_ data: Data, _ offset: inout Int, _ length: UInt32) -> Data {
        guard offset >= 0, offset <= data.count else { return Data() }
        let requested = Int(length)
        let available = data.count - offset
        let count = min(max(requested, 0), available)
        let value = data.subdata(in: offset..<(offset + count))
        offset += count
        return value
    }
    
    static func getString(_ data: Data, _ offset: inout Int, length: Int = 0) -> String {
        guard offset < data.count else { return "" }
        let textEncoding = getUInt8(data, &offset)
        if length > 0 {
            let payloadLength = max(length - 1, 0)
            let end = min(offset + payloadLength, data.count)
            guard offset <= end else { return "" }
            let str = decodeData(data[offset..<end], getEncoding(textEncoding))
            offset = end
            return str
        } else {
            let value = data[offset..<data.count].prefix(while: { $0 != 0x00 })
            offset = min(offset + value.count + 1, data.count)
            return decodeData(Data(value), getEncoding(textEncoding))
        }
    }

    static func decodeTextFrameBody(_ body: Data) -> String {
        guard let encodingByte = body.first else { return "" }
        let decoded = decodeData(body.dropFirst(), getEncoding(encodingByte))
        return decoded
            .replacingOccurrences(of: "\0", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func ctocChildIDs(from body: Data) -> [String] {
        let bytes = [UInt8](body)
        guard let nullIndex = bytes.firstIndex(of: 0), nullIndex + 2 < bytes.count else { return [] }
        var offset = nullIndex + 1
        offset += 1
        let count = Int(bytes[offset])
        offset += 1
        var ids: [String] = []
        for _ in 0..<count {
            guard offset < bytes.count else { break }
            let idBytes = bytes[offset...].prefix(while: { $0 != 0 })
            if let id = String(bytes: idBytes, encoding: .isoLatin1), !id.isEmpty {
                ids.append(id)
            }
            offset += idBytes.count + 1
        }
        return ids
    }

    static func readFrames(from mp3: Data) throws -> [(name: String, body: Data)] {
        guard mp3.count >= 10, String(data: mp3.prefix(3), encoding: .isoLatin1) == "ID3" else {
            throw ID3ParserError.missingTag
        }
        let version = mp3[3]
        guard version == 3 else {
            throw ID3ParserError.unsupportedVersion(version)
        }
        let tagSize = unsynchsafe(mp3.subdata(in: 6..<10))
        let tagEnd = min(10 + tagSize, mp3.count)
        var offset = 10
        var frames: [(name: String, body: Data)] = []

        while offset + 10 <= tagEnd {
            let nameData = mp3.subdata(in: offset..<(offset + 4))
            if nameData.allSatisfy({ $0 == 0 }) {
                break
            }
            let name = String(data: nameData, encoding: .isoLatin1) ?? ""
            guard name.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else {
                break
            }
            offset += 4
            let length = Int(getUInt32(mp3, &offset))
            _ = getUInt16(mp3, &offset)
            let body = getData(mp3, &offset, UInt32(max(length, 0)))
            frames.append((name, body))
        }

        return frames
    }
    
    static func getEncoding(_ encoding: UInt8) -> ID3StringEncoding {
        switch encoding {
        case 0:
            return ID3StringEncoding.ASCII
        case 1:
            return ID3StringEncoding.UCS2
        case 2:
            return ID3StringEncoding.UTF16BE
        case 3:
            return ID3StringEncoding.UTF8
        default:
            return ID3StringEncoding.ASCII
        }
    }
    
    static func toTrackTime(millis: UInt32, showHours: Bool = false, showMillis: Bool = false) -> String {
        let tenths = (millis % 1000) / 100
        let sec = millis / 1000
        let s = sec % 60
        let min = sec / 60
        let m = min % 60
        let h = min / 60

        if showMillis {
            if showHours {
                return String(format: "%i:%02i:%02i.%01i", h, m, s, tenths)
            } else {
                return String(format: "%i:%02i.%01i", min, s, tenths)
            }
        } else {
            if showHours {
                return String(format: "%i:%02i:%02i", h, m, s)
            } else {
                return String(format: "%i:%02i", min, s)
            }
        }
    }
    
    static func parseTrackTime(_ track: String) -> UInt32? {
        let trimmed = track.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard (1...3).contains(parts.count) else { return nil }

        func milliseconds(from secondsField: String) -> UInt32? {
            guard let seconds = Float(secondsField), seconds >= 0 else { return nil }
            return UInt32(seconds * 1000)
        }

        if parts.count == 1 {
            return milliseconds(from: parts[0])
        }

        if parts.count == 2 {
            guard let minutes = UInt32(parts[0]), let secondMillis = milliseconds(from: parts[1]) else {
                return nil
            }
            return (minutes * 60 * 1000) + secondMillis
        }

        guard let hours = UInt32(parts[0]),
              let minutes = UInt32(parts[1]),
              let secondMillis = milliseconds(from: parts[2])
        else {
            return nil
        }
        return (hours * 60 * 60 * 1000) + (minutes * 60 * 1000) + secondMillis
    }

    static func trackToMillis(_ track: String) -> UInt32 {
        parseTrackTime(track) ?? 0
    }
}
