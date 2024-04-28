//
//  Chapter.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
import AVFoundation

struct Chapter: Identifiable, Hashable {
    let id = UUID()
    var title: String = ""
    var startTime: UInt32 = 0
    var endTime: UInt32 = 0
    var image: NSImage? = nil
    
    init(data: Data) {
        print("datalen: \(data.count)")
        let toc = data.prefix(while: {$0 != 0x00})
        print("toc: \(String(decoding: toc, as: UTF8.self))")
        var offset = toc.count+1
        print("toc len: \(offset)")
        //        var endIdx = startIdx+4
        self.startTime = getUInt32(data, &offset)
        print("startTime: \(startTime); offset: \(offset)")
        self.endTime = getUInt32(data, &offset)
        print("endTime: \(endTime); offset: \(offset)")
        let startOffset: UInt32 = getUInt32(data, &offset)
        print("startOffset: \(startOffset); offset: \(offset)")
        let endOffset: UInt32 = getUInt32(data, &offset)
        print("endOffset: \(endOffset); offset: \(offset)")
        var tag = getTag(data, &offset)
        print("tag: \(tag)")
        if "TIT2" == tag {
            // Loop through Title details
            let tit2Len = getUInt32(data, &offset)
            let tit2Flags = getUInt16(data, &offset)
            let tit2Info = getString(data, &offset, length: Int(tit2Len))
            print("len: \(tit2Len); flags: \(tit2Flags); title: \(tit2Info)")
            title = tit2Info
        }
        tag = getTag(data, &offset)
        
        

        print("\(String(decoding: data, as: UTF8.self))")
    }
    
    enum ID3StringEncoding {
        case ASCII
        case UCS2
        case UTF16BE
        case UTF8
    }
    
    func getEncoding(_ encoding: UInt8) -> ID3StringEncoding {
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
    
   
//    func decodeString(_ data: Data, )
    
    
    func getTag(_ data: Data, _ offset: inout Int) -> String {
        let end: Int = offset + 4
        let str = String(decoding: data[offset..<end], as:UTF8.self)
        offset = end
        return str
    }
    
    func decodeString(_ data: Data, _ encoding: ID3StringEncoding) -> String {
        
//        if ib[0] == 0xFF && ib[1] == 0xFE {
//            ib = Array(ib.dropFirst(2))
//        }
//        let str = String(decoding: ib, as:UTF8.self)
        switch encoding {
        case .ASCII:
            return String(data: data, encoding: .ascii)!
        case .UCS2:
            return String(data: data, encoding: .utf16)!
        case .UTF16BE:
            return String(data: data, encoding: .utf16)!
        case .UTF8:
            return String(data: data, encoding: .utf8)!
        default:
            return String(data: data, encoding: .ascii)!
        }
        
        
    }
    
    func getString(_ data: Data, _ offset: inout Int, length: Int) -> String {
        let textEncoding = getUInt8(data, &offset)
        let end: Int = offset + length - 1 // -1 for the textEncoding
//        var ib:[UInt8] = [UInt8](data[offset..<end])
        let str: String = decodeString(data[offset..<end], getEncoding(textEncoding))
        offset = end
        return str
    }
    
    func getUInt8(_ data: Data, _ offset: inout Int) -> UInt8 {
        let end: Int = offset+1
        let ib:[UInt8] = [UInt8](data[offset..<end])
        let bigEndianUInt8 = UInt8(bigEndian: ib.withUnsafeBytes { $0.load(as: UInt8.self)})
        offset = end
        return bigEndianUInt8
    }
    
    func getUInt16(_ data: Data, _ offset: inout Int) -> UInt16 {
        let end: Int = offset+2
        let ib:[UInt8] = [UInt8](data[offset..<end])
        let bigEndianUInt16 = UInt16(bigEndian: ib.withUnsafeBytes { $0.load(as: UInt16.self)})
        offset = end
        return bigEndianUInt16
    }
    
    func getUInt32(_ data: Data, _ offset: inout Int) -> UInt32 {
        let end: Int = offset+4
        let ib:[UInt8] = [UInt8](data[offset..<end])
        let bigEndianUInt32 = UInt32(bigEndian: ib.withUnsafeBytes { $0.load(as: UInt32.self)})
        offset = end
        return bigEndianUInt32
    }
    
    
    func getImage() -> NSImage {
        if image != nil {
            return image!
        } else {
            return NSImage(systemSymbolName:"photo.badge.plus", accessibilityDescription: "Add Image")!
        }
    }
}
