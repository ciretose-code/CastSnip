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
    static let playPause = "PlayPause"
    static let back10 = "Back 10 seconds"
    static let forward10 = "Forward 10 seconds"
    static let viewport = "Waveform zoom"
    static let podcastTitle = "Podcast title"
    static let episodeTitle = "Episode title"
    static let authors = "Authors"
    static let addChapter = "Add chapter"
    static let emptyEditor = "Empty editor"
    static let encoding = "Encoding"

    static func chapterRow(title: String, start: String, end: String) -> String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = name.isEmpty ? "Untitled chapter" : name
        return "\(display), \(start) to \(end)"
    }
}

enum UITestOpenSource: Equatable {
    case sample
    case file(URL)
}

struct UITestLaunchArguments: Equatable {
    static let openFlag = "-UITestOpen"
    static let saveAsFlag = "-UITestSaveAs"
    static let encodeFlag = "-UITestEncode"
    static let sampleToken = "sample"

    var openSource: UITestOpenSource?
    var saveAsURL: URL?
    var encodeURL: URL?

    var isActive: Bool {
        openSource != nil || saveAsURL != nil || encodeURL != nil
    }

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        openSource = Self.value(after: Self.openFlag, in: arguments).map { token in
            token.lowercased() == Self.sampleToken
                ? .sample
                : .file(URL(fileURLWithPath: token))
        }
        saveAsURL = Self.value(after: Self.saveAsFlag, in: arguments).map(Self.resolvedDestination)
        encodeURL = Self.value(after: Self.encodeFlag, in: arguments).map(Self.resolvedDestination)
    }

    func resolvedOpenURL(in bundle: Bundle = .main) -> URL? {
        switch openSource {
        case .sample:
            return SampleEpisode.url(in: bundle)
        case .file(let url):
            return url
        case nil:
            return nil
        }
    }

    /// Absolute paths stay as-is. Bare filenames go in the process temporary directory so
    /// a sandboxed UI test runner does not have to create a shared folder first.
    static func resolvedDestination(_ token: String) -> URL {
        if token.hasPrefix("/") {
            return URL(fileURLWithPath: token)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent(token)
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let next = index + 1
        guard next < arguments.count else { return nil }
        let value = arguments[next]
        guard !value.hasPrefix("-") else { return nil }
        return value
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
