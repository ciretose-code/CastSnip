//
//  SecurityScopedBookmarkStore.swift
//  CastSnip
//

import Foundation

final class SecurityScopedBookmarkStore {
    static let shared = SecurityScopedBookmarkStore()

    private let defaults: UserDefaults
    private let defaultsKey = "securityScopedBookmarks"
    private var activeURLs: [URL] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func rememberAndAccess(_ url: URL) {
        if url.startAccessingSecurityScopedResource() {
            activeURLs.append(url)
        }

        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var map = defaults.dictionary(forKey: defaultsKey) as? [String: Data] ?? [:]
            map[url.path] = data
            defaults.set(map, forKey: defaultsKey)
        } catch {
            // Bookmarks can fail for bundle resources and test temp files.
        }
    }

    func resolveAndAccess(path: String) -> URL? {
        let map = defaults.dictionary(forKey: defaultsKey) as? [String: Data] ?? [:]
        var stale = false
        if let data = map[path],
           let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
           ) {
            if url.startAccessingSecurityScopedResource() {
                activeURLs.append(url)
            }
            return url
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        rememberAndAccess(url)
        return url
    }

    func stopAll() {
        for url in activeURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeURLs.removeAll()
    }
}
