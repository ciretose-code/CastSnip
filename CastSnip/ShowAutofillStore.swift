//
//  ShowAutofillStore.swift
//  CastSnip
//

import Foundation
import AppKit

struct ShowAutofillSuggestion {
    var title: String?
    var episode: String?
    var artwork: NSImage?
}

struct ChapterAutofillSuggestion {
    var url: String?
    var image: NSImage?
}

struct StoredShowAutofill: Identifiable {
    var prefix: String
    var title: String
    var artwork: NSImage?

    var id: String { prefix }
}

struct StoredChapterAutofill: Identifiable {
    var title: String
    var url: String?
    var image: NSImage?

    var id: String { title }
}

final class ShowAutofillStore {
    static let shared = ShowAutofillStore()
    static let showsKey = "showAutofillShows"
    static let chaptersKey = "showAutofillChapters"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func rememberShow(prefix: String, title: String, artwork: NSImage?) {
        let key = prefix.lowercased()
        guard !key.isEmpty, !title.isEmpty else { return }

        var shows = loadShows()
        shows[key] = ShowRecord(title: title, artwork: imageData(from: artwork))
        saveShows(shows)
    }

    func suggestion(forFilename filename: String) -> ShowAutofillSuggestion {
        guard !shouldIgnore(filename), let parsed = Self.parse(filename) else {
            return ShowAutofillSuggestion()
        }

        let record = loadShows()[parsed.prefix]
        return ShowAutofillSuggestion(
            title: record?.title,
            episode: parsed.episode,
            artwork: image(from: record?.artwork)
        )
    }

    func rememberChapter(title: String, url: String, image: NSImage?) {
        let key = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return }
        guard !url.isEmpty || image != nil else { return }

        var chapters = loadChapters()
        chapters[key] = ChapterRecord(url: url, image: imageData(from: image))
        saveChapters(chapters)
    }

    func suggestion(forChapterTitle title: String) -> ChapterAutofillSuggestion {
        let key = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty, let record = loadChapters()[key] else {
            return ChapterAutofillSuggestion()
        }
        return ChapterAutofillSuggestion(
            url: record.url.isEmpty ? nil : record.url,
            image: image(from: record.image)
        )
    }

    func applyToPodcastIfEmpty(_ podcast: Podcast, filename: String) {
        let suggestion = suggestion(forFilename: filename)
        if podcast.title.isEmpty, let title = suggestion.title {
            podcast.title = title
        }
        if podcast.episode.isEmpty, let episode = suggestion.episode {
            podcast.episode = episode
        }
        if podcast.logo == nil, let artwork = suggestion.artwork {
            podcast.logo = artwork
        }
    }

    func applyToChapterIfEmpty(_ chapter: Chapter) {
        let suggestion = suggestion(forChapterTitle: chapter.title)
        if chapter.url.isEmpty, let url = suggestion.url {
            chapter.url = url
        }
        if chapter.image == nil, let image = suggestion.image {
            chapter.image = image
        }
    }

    func storedShows() -> [StoredShowAutofill] {
        loadShows()
            .map { key, record in
                StoredShowAutofill(
                    prefix: key,
                    title: record.title,
                    artwork: image(from: record.artwork)
                )
            }
            .sorted { $0.prefix < $1.prefix }
    }

    func storedChapters() -> [StoredChapterAutofill] {
        loadChapters()
            .map { key, record in
                StoredChapterAutofill(
                    title: key,
                    url: record.url.isEmpty ? nil : record.url,
                    image: image(from: record.image)
                )
            }
            .sorted { $0.title < $1.title }
    }

    func deleteShow(prefix: String) {
        let key = prefix.lowercased()
        guard !key.isEmpty else { return }
        var shows = loadShows()
        shows.removeValue(forKey: key)
        saveShows(shows)
    }

    func deleteChapter(title: String) {
        let key = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return }
        var chapters = loadChapters()
        chapters.removeValue(forKey: key)
        saveChapters(chapters)
    }

    func clear() {
        defaults.removeObject(forKey: Self.showsKey)
        defaults.removeObject(forKey: Self.chaptersKey)
    }

    static func parse(_ filename: String) -> (prefix: String, episode: String?)? {
        let name = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        guard let match = name.wholeMatch(of: /^([A-Za-z]+)[-_]?(\d+)?$/) else {
            return nil
        }
        let prefix = String(match.1).lowercased()
        let episode = match.2.map(String.init).flatMap { $0.isEmpty ? nil : $0 }
        return (prefix, episode)
    }

    private func shouldIgnore(_ filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        return filename.contains("/Contents/Resources/") || SampleEpisode.isSample(url)
    }

    private func loadShows() -> [String: ShowRecord] {
        decode(forKey: Self.showsKey) ?? [:]
    }

    private func saveShows(_ shows: [String: ShowRecord]) {
        encode(shows, forKey: Self.showsKey)
    }

    private func loadChapters() -> [String: ChapterRecord] {
        decode(forKey: Self.chaptersKey) ?? [:]
    }

    private func saveChapters(_ chapters: [String: ChapterRecord]) {
        encode(chapters, forKey: Self.chaptersKey)
    }

    private func decode<T: Decodable>(forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func imageData(from image: NSImage?) -> Data? {
        image?.tiffRepresentation
    }

    private func image(from data: Data?) -> NSImage? {
        guard let data else { return nil }
        return NSImage(data: data)
    }
}

private struct ShowRecord: Codable {
    var title: String
    var artwork: Data?
}

private struct ChapterRecord: Codable {
    var url: String
    var image: Data?
}
