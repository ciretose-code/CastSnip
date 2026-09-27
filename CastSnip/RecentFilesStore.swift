//
//  RecentFilesStore.swift
//  CastSnip
//

import Foundation
import Observation

@Observable
final class RecentFilesStore {
    static let shared = RecentFilesStore()
    static let defaultsKey = "recentPodcastFiles"
    static let maxCount = 10

    private let defaults: UserDefaults
    private(set) var entries: [String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.entries = defaults.stringArray(forKey: Self.defaultsKey) ?? []
    }

    func remember(_ url: URL) {
        guard !isBundledSample(url) else { return }

        var next = entries.filter { $0 != url.path }
        next.insert(url.path, at: 0)
        if next.count > Self.maxCount {
            next = Array(next.prefix(Self.maxCount))
        }
        entries = next
        defaults.set(next, forKey: Self.defaultsKey)
    }

    func paths() -> [String] {
        entries
    }

    func urls() -> [URL] {
        paths().map { URL(fileURLWithPath: $0) }
    }

    func clear() {
        entries = []
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    private func isBundledSample(_ url: URL) -> Bool {
        url.path.contains("/Contents/Resources/")
    }
}
