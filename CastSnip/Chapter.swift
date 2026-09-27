//
//  Chapter.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/8/24.
//

import SwiftUI
import AppKit

enum ChapterValidationError {
    case invalidTimeRange
    case startTimeExceedsDuration
    case endTimeExceedsDuration
    case emptyTitle
    case invalidURL
}

@Observable
class Chapter: Identifiable, Equatable, Comparable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    static let DEFAULT_TITLE = "Chapter Title"
    static let DEFAULT_URL = "Chapter Link"

    let id = UUID()
    var title: String = ""
    var url: String = ""
    var startTime: UInt32 = 0
    var endTime: UInt32 = 0
    var podcastDuration: UInt32 = 0
    var image: NSImage? = nil
    var imageDescription: String = ""
    
    var description: String {
        return "\nUUID: \(id)\nTitle: \(title)\nURL: \(url)\nStart: \(startTime)\nEnd: \(endTime)\nPodcast: \(podcastDuration)\nImage: \(String(describing: image))\nImage Description: \(imageDescription)\n"
    }
    
    var debugDescription: String {
        return description
    }
    
    init() {}
    
    init(title: String = "", url: String = "", startTime: UInt32 = 1, endTime: UInt32 = 0, podcastDuration: UInt32 = 0) {
        self.title = title
        self.url = url
        self.startTime = startTime
        self.endTime = endTime
        self.podcastDuration = podcastDuration
    }
    
    init(data: Data, podcastDuration: UInt32 = 0) {
        self.podcastDuration = podcastDuration
//        print("Podcast Duration: \(podcastDuration)")
        let toc = data.prefix(while: {$0 != 0x00})
        var offset = toc.count+1
        startTime = ID3Parser.getUInt32(data, &offset)
        endTime = ID3Parser.getUInt32(data, &offset)
        let _ : UInt32 = ID3Parser.getUInt32(data, &offset) // startOffset
        let _ : UInt32 = ID3Parser.getUInt32(data, &offset) // endOffset
        
        while offset < data.count {
            let tag = ID3Parser.getTagHeader(data, &offset)
            if tag.name.isEmpty {
                break
            }
            if "TIT2" == tag.name {
                // Loop through Title details
                let tit2Info = ID3Parser.getString(data, &offset, length: Int(tag.length))
                title = tit2Info.trimmingCharacters(in: CharacterSet(charactersIn: "\0")).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if "WXXX" == tag.name {
                let wxxxInfo = ID3Parser.getString(data, &offset, length: Int(tag.length))
                let parts = wxxxInfo.components(separatedBy: "\0")
                if parts.count > 1 {
                    url = parts[1]
                } else if parts.count == 1, parts[0].contains("://") {
                    url = parts[0]
                } else {
                    url = ""
                }
            }
            if "APIC" == tag.name {
                _ = ID3Parser.getString(data, &offset)
                _ = ID3Parser.getUInt8(data, &offset)
                var checkOffset = offset
                if offset < data.count, ID3Parser.getUInt8(data, &checkOffset) == 0x00 {
                    // No description, skip it
                    offset = offset + 1
                } else if offset < data.count {
                    let apicDescription = ID3Parser.getString(data, &offset)
                    imageDescription = apicDescription
                }
                let remaining = UInt32(max(data.count - offset, 0))
                let apicImageData = ID3Parser.getData(data, &offset, remaining)
                image = NSImage(data: apicImageData)
            }
        }
    }

    func updateImage(_ newImage: NSImage?) {
        if newImage != nil {
            self.image = newImage
        }
    }
    
    func updateTitle(_ newTitle: String) {
        self.title = newTitle
    }
    
    func validate() -> [ChapterValidationError] {
        var errors: [ChapterValidationError] = []
        
        if startTime >= endTime && endTime != 0 {
            errors.append(.invalidTimeRange)
        }
        
        if startTime > podcastDuration && podcastDuration != 0 {
            errors.append(.startTimeExceedsDuration)
        }
        
        if endTime > podcastDuration && podcastDuration != 0 {
            errors.append(.endTimeExceedsDuration)
        }
        
        if title.isEmpty {
            errors.append(.emptyTitle)
        }
        
        if !url.isEmpty {
            if let urlObj = URL(string: url) {
                if urlObj.scheme == nil || urlObj.host == nil {
                    errors.append(.invalidURL)
                }
            } else {
                errors.append(.invalidURL)
            }
        }
        
        return errors
    }
    
    func isValid() -> Bool {
        return validate().isEmpty
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func < (lhs: Chapter, rhs: Chapter) -> Bool {
        return lhs.startTime < rhs.startTime
    }
    
    static func > (lhs: Chapter, rhs: Chapter) -> Bool {
        return lhs.startTime > rhs.startTime
    }
    
    static func == (lhs: Chapter, rhs: Chapter) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func != (lhs: Chapter, rhs: Chapter) -> Bool {
        return lhs.id != rhs.id
    }
    
    
    
}

