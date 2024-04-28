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
    var url: String = ""
    var startTime: UInt32 = 0
    var endTime: UInt32 = 0
    var image: NSImage? = nil
    
    init() {}
    
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

        while offset < data.count {
            print("pretag offset: \(offset)")
            let tag = getTagHeader(data, &offset)
            print("tag: \(tag)")
            print("tag offset: \(offset)")
            if "TIT2" == tag.name {
                // Loop through Title details
//                let tit2Len = getUInt32(data, &offset)
//                let tit2Flags = getUInt16(data, &offset)
                let tit2Info = getString(data, &offset, length: Int(tag.length))
                print("title: \(tit2Info)")
                title = tit2Info
            }
            if "WXXX" == tag.name {
//                let wxxxLen = getUInt32(data, &offset)
//                let wxxxFlags = getUInt16(data, &offset)
                let wxxxInfo = getString(data, &offset, length: Int(tag.length))
                url = wxxxInfo.components(separatedBy: "\0")[1]
                print("string: \(wxxxInfo); url: \(url)")
            }
            if "APIC" == tag.name {
                print("apic offset: \(offset)")
//                let apicLen = getUInt32(data, &offset)
//                let apicFlags = getUInt16(data, &offset)
                _ = getString(data, &offset)
//                print("mimetype offset: \(offset)")
                _ = getUInt8(data, &offset)
//                print("pictype offset: \(offset)")
                var checkOffset = offset
                if getUInt8(data, &checkOffset) == 0x00 {
                    // No description, skip it
                    offset = offset + 1
                } else {
                    let apicDescription = getString(data, &offset)
                }
//                print("desc offset: \(offset)")
                let apicImageData = getData(data, &offset, UInt32(data.count))
//                print("imagedata offset: \(offset)")
//                try! apicImageData.write(to: URL(fileURLWithPath: "/Users/ewuehler/Downloads/\(title).png"))
//                print("data.count: \(data.count)")
//                let imgRep = NSImageRep()
//                let can = NSImageRep.canInit(with: apicImageData)
//                print("can create image: \(can)")
//                print("types: \(NSImageRep.imageTypes)")
                image = NSImage(data: apicImageData)
//                print("apicImageData: \(String(decoding:apicImageData, as: UTF8.self))")
//                print("image: \(String(describing: image))")
            }
        }
    }
    
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
    
    
    func getTagHeader(_ data: Data, _ offset: inout Int) -> ID3TagHeader {
        let end: Int = offset + 4
        let name = String(decoding: data[offset..<end], as:UTF8.self)
        offset = end
        let length = getUInt32(data, &offset)
        let flags = getUInt16(data, &offset)
        return ID3TagHeader(name:name, length:length, flags:flags)
    }
    
    func decodeData(_ data: Data, _ encoding: ID3StringEncoding) -> String {
        switch encoding {
        case .ASCII:
            return String(data: data, encoding: .ascii)!
        case .UCS2:
            return String(data: data, encoding: .utf16)!
        case .UTF16BE:
            return String(data: data, encoding: .utf16)!
        case .UTF8:
            return String(data: data, encoding: .utf8)!
        }
    }
    
    func getData(_ data: Data, _ offset: inout Int, _ length: UInt32) -> Data {
//        let value = data[offset..<Int(length)]
        let value = data.subdata(in: offset..<Int(length))
        offset = data.count
        return value
    }
    
    func getString(_ data: Data, _ offset: inout Int, length: Int = 0) -> String {
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
