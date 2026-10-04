//
//  EncodeBitrate.swift
//  CastSnip
//
//  CBR bitrate choices for Encode to MP3.
//

import Foundation

enum EncodeBitrate: Int, CaseIterable, Equatable, Identifiable, Sendable {
    case kbps64 = 64
    case kbps96 = 96
    case kbps128 = 128
    case kbps192 = 192

    /// Forecast-class default; used when preference is missing or invalid.
    static let podcastDefault = kbps192

    var id: Int { rawValue }

    var menuTitle: String { "\(rawValue) kbps" }

    static func resolved(_ raw: Int) -> EncodeBitrate {
        EncodeBitrate(rawValue: raw) ?? .podcastDefault
    }
}
