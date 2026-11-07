import Foundation
import Testing
@testable import CastSnip

@Suite("Release Check Tests")
struct ReleaseCheckManagerTests {

    @Test("App release version appends build number to short version")
    func appReleaseVersionUsesBuildNumber() {
        let version = AppReleaseVersion(shortVersion: "1.0", buildVersion: "5")

        #expect(version?.displayString == "1.0.5")
    }

    @Test("Release versions compare numerically")
    func releaseVersionsCompareNumerically() {
        let currentVersion = ReleaseVersion(string: "v1.0.5")
        let olderVersion = ReleaseVersion(string: "1.0.4")
        let shorterVersion = ReleaseVersion(string: "1.0")

        #expect(currentVersion != nil)
        #expect(olderVersion != nil)
        #expect(shorterVersion != nil)
        #expect(currentVersion! > olderVersion!)
        #expect(currentVersion! > shorterVersion!)
    }

    @Test("Update check reports available release")
    func updateAvailable() async throws {
        let currentVersion = try #require(AppReleaseVersion(shortVersion: "1.0", buildVersion: "4"))
        let checker = GitHubReleaseChecker(
            currentVersion: currentVersion,
            fetcher: MockReleaseFetcher(json: """
            {
              "tag_name": "v1.0.5",
              "html_url": "https://github.com/ewuehler/CastSnip/releases/tag/v1.0.5"
            }
            """)
        )

        let outcome = try await checker.checkForUpdates()

        #expect(outcome == .updateAvailable(
            currentVersion: "1.0.4",
            latestVersion: "1.0.5",
            releasePage: URL(string: "https://github.com/ewuehler/CastSnip/releases/tag/v1.0.5")!
        ))
    }

    @Test("Update check reports current version when already up to date")
    func updateNotNeeded() async throws {
        let currentVersion = try #require(AppReleaseVersion(shortVersion: "1.0", buildVersion: "5"))
        let checker = GitHubReleaseChecker(
            currentVersion: currentVersion,
            fetcher: MockReleaseFetcher(json: """
            {
              "tag_name": "v1.0.5",
              "html_url": "https://github.com/ewuehler/CastSnip/releases/tag/v1.0.5"
            }
            """)
        )

        let outcome = try await checker.checkForUpdates()

        #expect(outcome == .upToDate(currentVersion: "1.0.5"))
    }

    @Test("Update check fails for invalid release tag")
    func invalidReleaseTag() async {
        let currentVersion = AppReleaseVersion(shortVersion: "1.0", buildVersion: "5")
        let checker = GitHubReleaseChecker(
            currentVersion: currentVersion!,
            fetcher: MockReleaseFetcher(json: """
            {
              "tag_name": "latest",
              "html_url": "https://github.com/ewuehler/CastSnip/releases/tag/latest"
            }
            """)
        )

        await #expect(throws: ReleaseCheckError.invalidReleaseVersion("latest")) {
            try await checker.checkForUpdates()
        }
    }

    @Test("Automatic checks are enabled by default and respect a stored preference")
    func automaticChecksDefault() throws {
        let suiteName = "ReleaseCheckScheduleTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(ReleaseCheckSchedule.automaticChecksEnabled(using: defaults))

        defaults.set(false, forKey: ReleaseCheckSchedule.automaticChecksEnabledKey)
        #expect(!ReleaseCheckSchedule.automaticChecksEnabled(using: defaults))
    }

    @Test("Automatic check is due when never checked or a day has passed")
    func checkDue() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        #expect(ReleaseCheckSchedule.isCheckDue(lastCheck: nil, now: now))
        #expect(!ReleaseCheckSchedule.isCheckDue(lastCheck: now.addingTimeInterval(-60 * 60), now: now))
        #expect(ReleaseCheckSchedule.isCheckDue(lastCheck: now.addingTimeInterval(-24 * 60 * 60), now: now))
        #expect(ReleaseCheckSchedule.isCheckDue(lastCheck: now.addingTimeInterval(60 * 60), now: now))
    }

    @Test("Skipped version suppresses automatic notification only for that version")
    func skippedVersion() {
        #expect(ReleaseCheckSchedule.shouldNotify(latestVersion: "1.0.9", skippedVersion: nil))
        #expect(!ReleaseCheckSchedule.shouldNotify(latestVersion: "1.0.9", skippedVersion: "1.0.9"))
        #expect(ReleaseCheckSchedule.shouldNotify(latestVersion: "1.0.10", skippedVersion: "1.0.9"))
    }
}

private final class MockReleaseFetcher: ReleaseFetching {
    private let data: Data
    private let response: URLResponse

    init(json: String, statusCode: Int = 200) {
        self.data = Data(json.utf8)
        self.response = HTTPURLResponse(
            url: GitHubReleaseChecker.defaultReleasesURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        (data, response)
    }
}
