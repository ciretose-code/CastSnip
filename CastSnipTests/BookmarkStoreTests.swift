import Testing
import Foundation
@testable import CastSnip

struct BookmarkStoreTests {

    @Test func resolveAndAccessOfMissingPathReturnsNil() {
        let store = isolatedStore()
        let missing = "/tmp/castsnip-missing-bookmark-\(UUID().uuidString).mp3"

        #expect(store.resolveAndAccess(path: missing) == nil)
    }

    @Test func resolveAndAccessOfExistingTempFileReturnsThatURL() throws {
        let store = isolatedStore()
        let url = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let resolved = store.resolveAndAccess(path: url.path)

        #expect(resolved?.path == url.path)
    }

    @Test func stopAllDoesNotCrashAfterRememberAndAccess() throws {
        let store = isolatedStore()
        let url = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        store.rememberAndAccess(url)
        store.stopAll()
    }

    @Test func twoStoresWithDifferentSuitesDoNotShareMapEntries() throws {
        let suiteA = "CastSnip.BookmarkStoreTests.A.\(UUID().uuidString)"
        let suiteB = "CastSnip.BookmarkStoreTests.B.\(UUID().uuidString)"
        let defaultsA = UserDefaults(suiteName: suiteA)!
        let defaultsB = UserDefaults(suiteName: suiteB)!
        defaultsA.removePersistentDomain(forName: suiteA)
        defaultsB.removePersistentDomain(forName: suiteB)
        defer {
            defaultsA.removePersistentDomain(forName: suiteA)
            defaultsB.removePersistentDomain(forName: suiteB)
        }

        let storeA = SecurityScopedBookmarkStore(defaults: defaultsA)
        let storeB = SecurityScopedBookmarkStore(defaults: defaultsB)
        let fileA = try makeTempFile()
        let fileB = try makeTempFile()
        defer {
            try? FileManager.default.removeItem(at: fileA)
            try? FileManager.default.removeItem(at: fileB)
        }

        let key = "securityScopedBookmarks"
        defaultsA.set([fileA.path: Data([0xA])], forKey: key)
        defaultsB.set([fileB.path: Data([0xB])], forKey: key)

        storeA.rememberAndAccess(fileA)
        storeB.rememberAndAccess(fileB)
        _ = storeA.resolveAndAccess(path: fileA.path)
        _ = storeB.resolveAndAccess(path: fileB.path)

        let mapA = defaultsA.dictionary(forKey: key) as? [String: Data] ?? [:]
        let mapB = defaultsB.dictionary(forKey: key) as? [String: Data] ?? [:]

        #expect(mapA[fileA.path] != nil)
        #expect(mapB[fileB.path] != nil)
        #expect(mapA[fileB.path] == nil)
        #expect(mapB[fileA.path] == nil)
    }

    private func isolatedStore() -> SecurityScopedBookmarkStore {
        let suite = "CastSnip.BookmarkStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return SecurityScopedBookmarkStore(defaults: defaults)
    }

    private func makeTempFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-bookmark-\(UUID().uuidString).txt")
        try Data("bookmark-test".utf8).write(to: url)
        return url
    }
}
