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

class ID3Parser {
    
    static func getTagHeader(_ data: Data, _ offset: inout Int) -> ID3TagHeader {
        let end: Int = offset + 4
        let name = String(decoding: data[offset..<end], as:UTF8.self)
        offset = end
        let length = getUInt32(data, &offset)
        let flags = getUInt16(data, &offset)
        return ID3TagHeader(name:name, length:length, flags:flags)
    }
    
    static func getUInt8(_ data: Data, _ offset: inout Int) -> UInt8 {
        let end: Int = offset+1
        let ib:[UInt8] = [UInt8](data[offset..<end])
        let bigEndianUInt8 = UInt8(bigEndian: ib.withUnsafeBytes { $0.load(as: UInt8.self)})
        offset = end
        return bigEndianUInt8
    }
    
    static func getUInt16(_ data: Data, _ offset: inout Int) -> UInt16 {
        let end: Int = offset+2
        let ib:[UInt8] = [UInt8](data[offset..<end])
        let bigEndianUInt16 = UInt16(bigEndian: ib.withUnsafeBytes { $0.load(as: UInt16.self)})
        offset = end
        return bigEndianUInt16
    }
    
    static func getUInt32(_ data: Data, _ offset: inout Int) -> UInt32 {
        let end: Int = offset+4
        let ib:[UInt8] = [UInt8](data[offset..<end])
        let bigEndianUInt32 = UInt32(bigEndian: ib.withUnsafeBytes { $0.load(as: UInt32.self)})
        offset = end
        return bigEndianUInt32
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
//        let value = data[offset..<Int(length)]
        let value = data.subdata(in: offset..<Int(length))
        offset = data.count
        return value
    }
    
    static func getString(_ data: Data, _ offset: inout Int, length: Int = 0) -> String {
        let textEncoding = getUInt8(data, &offset)
        if length > 0 {
            let end: Int = offset + length - 1 // -1 for the textEncoding
            let str: String = decodeData(data[offset..<end], getEncoding(textEncoding))
            offset = end
            return str
        } else {
            // Walk until 0x00
            let value = data[offset..<data.count].prefix(while: {$0 != 0x00})
            offset = offset + value.count + 1 // Add one for the 0x00
            return decodeData(value, getEncoding(textEncoding))
        }
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
        let ms = (millis % 1000)
        let sec = millis / 1000
        let s = sec % 60
        let min = sec / 60
        let m = min % 60
        let h = min / 60

        if showMillis {
            if showHours {
                return String(format: "%i:%02i:%02i.%03i", h, m, s, ms)
            } else {
                return String(format: "%i:%02i.%03i", min, s, ms)
            }
        } else {
            if showHours {
                return String(format: "%i:%02i:%02i", h, m, s)
            } else {
                return String(format: "%i:%02i", min, s)
            }
        }
    }
    
    static func trackToMillis(_ track: String) -> UInt32 {
        let t = track.components(separatedBy: ":")
        if (t.count == 1) {
            if let seconds = Float(t[0]) {
                return UInt32(seconds * 1000)
            } else {
                return 0
            }
        } else if (t.count == 2) {
            if let minutes = UInt32(t[0]) {
                if let seconds = Float(t[1]) {
                    return (minutes * 60 * 1000) + UInt32(seconds * 1000)
                } else {
                    return (minutes * 60 * 1000)
                }
            } else {
                return 0
            }
        } else if (t.count == 3) {
            if let hours = UInt32(t[0]) {
                if let minutes = UInt32(t[1]) {
                    if let seconds = Float(t[2]) {
                        return (hours * 60 * 60 * 1000) + (minutes * 60 * 1000) + UInt32(seconds * 1000)
                    } else {
                        return minutes * 60 * 1000
                    }
                } else {
                    return (hours * 60 * 60 * 1000)
                }
            } else {
                return 0
            }
        } else {
            return 0
        }
    }
}
