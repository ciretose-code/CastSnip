//
//  SecurityScopedBookmarkStore.swift
//  CastSnip
//

import Foundation

final class SecurityScopedBookmarkStore {
    static let shared = SecurityScopedBookmarkStore()

    private let defaultsKey = "securityScopedBookmarks"
    private var activeURLs: [URL] = []

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
            var map = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data] ?? [:]
            map[url.path] = data
            UserDefaults.standard.set(map, forKey: defaultsKey)
        } catch {
            // Bookmarks can fail for bundle resources and test temp files.
        }
    }

    func stopAll() {
        for url in activeURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeURLs.removeAll()
    }
}
