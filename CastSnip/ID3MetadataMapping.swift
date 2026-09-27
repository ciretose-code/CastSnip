//
//  ID3MetadataMapping.swift
//  CastSnip
//

import Foundation

enum ID3MetadataMapping {
    static func applyString(key: String, value: String, to podcast: Podcast) {
        switch key {
        case "TALB":
            podcast.title = value
        case "TIT2":
            podcast.episode = value
        case "TPE1":
            podcast.artist = value
        case "COMM":
            podcast.summary = value
        case "USLT":
            if podcast.summary.isEmpty {
                podcast.summary = value
            }
        case "TLEN":
            if let tlen = UInt32(value), tlen > 0, (podcast.durationInMillis ?? 0) == 0 {
                podcast.durationInMillis = tlen
            }
        default:
            break
        }
    }
}
