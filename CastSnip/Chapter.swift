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
    #if os(iOS)
    var image: UIImage? = nil
    #else
    var image: NSImage? = nil
    #endif
    var imageDescription: String = ""
    
    init() {}
    
    init(title: String = "", url: String = "", startTime: UInt32 = 0, endTime: UInt32 = 0) {
        self.title = title
        self.url = url
        self.startTime = startTime
        self.endTime = endTime
    }
    
    init(data: Data) {
        let toc = data.prefix(while: {$0 != 0x00})
        var offset = toc.count+1
        startTime = ID3Parser.getUInt32(data, &offset)
        endTime = ID3Parser.getUInt32(data, &offset)
        let _ : UInt32 = ID3Parser.getUInt32(data, &offset) // startOffset
        let _ : UInt32 = ID3Parser.getUInt32(data, &offset) // endOffset

        while offset < data.count {
            let tag = ID3Parser.getTagHeader(data, &offset)
            if "TIT2" == tag.name {
                // Loop through Title details
                let tit2Info = ID3Parser.getString(data, &offset, length: Int(tag.length))
                title = tit2Info
            }
            if "WXXX" == tag.name {
                let wxxxInfo = ID3Parser.getString(data, &offset, length: Int(tag.length))
                url = wxxxInfo.components(separatedBy: "\0")[1]
            }
            if "APIC" == tag.name {
                _ = ID3Parser.getString(data, &offset)
                _ = ID3Parser.getUInt8(data, &offset)
                var checkOffset = offset
                if ID3Parser.getUInt8(data, &checkOffset) == 0x00 {
                    // No description, skip it
                    offset = offset + 1
                } else {
                    let apicDescription = ID3Parser.getString(data, &offset)
                    imageDescription = apicDescription
                }
                let apicImageData = ID3Parser.getData(data, &offset, UInt32(data.count))
                #if os(iOS)
                image = UIImage(data: apicImageData)
                #else
                image = NSImage(data: apicImageData)
                #endif
            }
        }
    }
        
//    func getImage() -> NSImage? {
//        if image != nil {
//            return image!
//        } else {
//            return NSImage(systemSymbolName:"photo.badge.plus", accessibilityDescription: "Add Image")!
//        }
//    }
}
