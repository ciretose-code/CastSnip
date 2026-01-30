//
//  Podcast.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/8/24.
//

import SwiftUI
import AVFoundation


@Observable
class Podcast {
    var url:URL?
    #if os(iOS)
    var logo:UIImage?
    #else
    var logo:NSImage?
    #endif
    var durationInSeconds:CGFloat?
    var durationInMillis:UInt32?
    var fileSizeInBytes:UInt64?
    var chapters:[Chapter] = []
    var asset:AVURLAsset?
    var file:AVAudioFile?
    var title:String = ""
    var episode:String = ""
    var summary:String = ""
    
    func getFileSizeFormatted() -> String {
        guard let size = fileSizeInBytes else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}
