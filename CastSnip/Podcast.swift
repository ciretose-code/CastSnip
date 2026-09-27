//
//  Podcast.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/8/24.
//

import SwiftUI
import AVFoundation
import AppKit


@Observable
class Podcast {
    var url:URL?
    var logo:NSImage?
    var durationInSeconds:CGFloat?
    var durationInMillis:UInt32?
    var fileSizeInBytes:UInt64?
    var chapters:[Chapter] = []
    var asset:AVURLAsset?
    var file:AVAudioFile?
    var title:String = ""
    var episode:String = ""
    var summary:String = ""
    var artist:String = ""
    
    func getFileSizeFormatted() -> String {
        guard let size = fileSizeInBytes else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    func getDurationFormatted() -> String {
        ID3Parser.toTrackTime(millis: durationInMillis ?? UInt32((durationInSeconds ?? 0) * 1000), showHours: true)
    }
    
    var shouldShowHours: Bool {
        return (durationInSeconds ?? 0) > 3600
    }
    
    func validateChapters() -> Bool {
        Self.chaptersDoNotOverlap(chapters)
    }

    static func chaptersDoNotOverlap(_ chapters: [Chapter]) -> Bool {
        let sorted = chapters.sorted()
        guard sorted.count > 1 else { return true }
        for i in 0..<(sorted.count - 1) {
            if sorted[i].endTime > sorted[i + 1].startTime {
                return false
            }
        }
        return true
    }
}
