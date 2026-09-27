//
//  EditorCopy.swift
//  CastSnip
//

import Foundation
import SwiftUI

enum EmptyEditorCopy {
    static let title = "Open an audio file to start"
    static let detail = "Drop an MP3, WAV, or M4A here, or choose File → Open."
    static let chapters = "Add a chapter at the playhead, or open a WAV with editor markers to import them."
}

enum SampleEpisode {
    static func url(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "intro", withExtension: "mp3")
    }

    static func isSample(_ url: URL) -> Bool {
        url.lastPathComponent == "intro.mp3" && url.path.contains("/Contents/Resources/")
    }
}

enum EditorAccessibility {
    static let coverArt = "Cover art"
    static let coverArtHint = "Opens an image picker"
    static let play = "Play"
    static let pause = "Pause"
    static let back10 = "Back 10 seconds"
    static let forward10 = "Forward 10 seconds"
    static let viewport = "Waveform zoom"

    static func chapterRow(title: String, start: String, end: String) -> String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = name.isEmpty ? "Untitled chapter" : name
        return "\(display), \(start) to \(end)"
    }
}

enum OptionalAlert {
    static func isPresented(_ message: Binding<String?>) -> Binding<Bool> {
        Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )
    }
}
