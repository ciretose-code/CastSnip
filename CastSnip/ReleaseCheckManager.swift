import AppKit
import Combine
import Foundation

struct ReleaseVersion: Comparable {
    let components: [Int]

    init?(string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstDigit = trimmed.firstIndex(where: \.isNumber) else { return nil }

        let numericPrefix = trimmed[firstDigit...].prefix { $0.isNumber || $0 == "." }
        let parsedComponents = numericPrefix
            .split(separator: ".")
            .compactMap { Int($0) }

        guard !parsedComponents.isEmpty else { return nil }
        components = parsedComponents
    }

    private init(components: [Int]) {
        self.components = components
    }

    var displayString: String {
        components.map(String.init).joined(separator: ".")
    }

    static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)

        for index in 0..<maxCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0

            if left != right {
                return left < right
            }
        }

        return false
    }

    static func appVersion(shortVersion: String, buildVersion: String?) -> ReleaseVersion? {
        guard let baseVersion = ReleaseVersion(string: shortVersion) else { return nil }

        // GitHub releases are tagged with a three-part version, while the bundle
        // uses MARKETING_VERSION for major/minor and CURRENT_PROJECT_VERSION for patch.
        if baseVersion.components.count == 2,
           let buildVersion,
           let buildNumber = Int(buildVersion) {
            return ReleaseVersion(components: baseVersion.components + [buildNumber])
        }

        return baseVersion
    }
}

struct AppReleaseVersion {
    let version: ReleaseVersion

    init?(shortVersion: String, buildVersion: String?) {
        guard let version = ReleaseVersion.appVersion(shortVersion: shortVersion, buildVersion: buildVersion) else {
            return nil
        }

        self.version = version
    }

    init?(bundle: Bundle) {
        guard let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return nil
        }

        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        self.init(shortVersion: shortVersion, buildVersion: buildVersion)
    }

    var displayString: String {
        version.displayString
    }
}

enum ReleaseCheckOutcome: Equatable {
    case updateAvailable(currentVersion: String, latestVersion: String, releasePage: URL)
    case upToDate(currentVersion: String)
}

enum ReleaseCheckError: Equatable, LocalizedError {
    case invalidCurrentVersion
    case invalidResponse
    case invalidReleaseVersion(String)
    case httpStatus(Int)
    case noPublishedRelease

    var errorDescription: String? {
        switch self {
        case .invalidCurrentVersion:
            return "This build does not expose a valid app version."
        case .invalidResponse:
            return "GitHub returned an unexpected response."
        case .invalidReleaseVersion(let tag):
            return "The latest release tag \"\(tag)\" is not a version CastSnip can compare."
        case .httpStatus(let statusCode):
            return "GitHub returned HTTP \(statusCode) while checking for updates."
        case .noPublishedRelease:
            return "No GitHub release is published yet."
        }
    }
}

protocol ReleaseFetching {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: ReleaseFetching {}

struct GitHubReleaseChecker {
    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    static let defaultReleasesURL = URL(string: "https://api.github.com/repos/ciretose-code/CastSnip/releases/latest")!

    private let currentVersion: AppReleaseVersion
    private let fetcher: ReleaseFetching
    private let releasesURL: URL

    init(
        currentVersion: AppReleaseVersion,
        fetcher: ReleaseFetching = URLSession.shared,
        releasesURL: URL = GitHubReleaseChecker.defaultReleasesURL
    ) {
        self.currentVersion = currentVersion
        self.fetcher = fetcher
        self.releasesURL = releasesURL
    }

    init?(bundle: Bundle = .main, fetcher: ReleaseFetching = URLSession.shared) {
        guard let currentVersion = AppReleaseVersion(bundle: bundle) else { return nil }
        self.init(currentVersion: currentVersion, fetcher: fetcher)
    }

    func checkForUpdates() async throws -> ReleaseCheckOutcome {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CastSnip/\(currentVersion.displayString)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await fetcher.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReleaseCheckError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw ReleaseCheckError.noPublishedRelease
            }

            throw ReleaseCheckError.httpStatus(httpResponse.statusCode)
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard let latestVersion = ReleaseVersion(string: release.tagName) else {
            throw ReleaseCheckError.invalidReleaseVersion(release.tagName)
        }

        if latestVersion > currentVersion.version {
            return .updateAvailable(
                currentVersion: currentVersion.displayString,
                latestVersion: latestVersion.displayString,
                releasePage: release.htmlURL
            )
        }

        return .upToDate(currentVersion: currentVersion.displayString)
    }
}

enum ReleaseCheckSchedule {
    static let automaticChecksEnabledKey = "automaticallyCheckForUpdates"
    static let lastCheckDateKey = "lastUpdateCheckDate"
    static let skippedVersionKey = "skippedUpdateVersion"

    static let checkInterval: TimeInterval = 24 * 60 * 60
    static let pollInterval: TimeInterval = 60 * 60
    static let launchDelay: TimeInterval = 10

    static func automaticChecksEnabled(using defaults: UserDefaults) -> Bool {
        guard defaults.object(forKey: automaticChecksEnabledKey) != nil else {
            return true
        }

        return defaults.bool(forKey: automaticChecksEnabledKey)
    }

    static func isCheckDue(lastCheck: Date?, now: Date, interval: TimeInterval = checkInterval) -> Bool {
        guard let lastCheck else { return true }

        // A last-check date in the future means the clock moved backwards; check again.
        return now.timeIntervalSince(lastCheck) >= interval || lastCheck > now
    }

    static func shouldNotify(latestVersion: String, skippedVersion: String?) -> Bool {
        latestVersion != skippedVersion
    }
}

@MainActor
final class ReleaseCheckManager: ObservableObject {
    @Published private(set) var isChecking = false
    @Published private(set) var automaticChecksEnabled: Bool

    private let makeChecker: () -> GitHubReleaseChecker?
    private let openURL: (URL) -> Void
    private let defaults: UserDefaults
    private let now: () -> Date
    private var pollTimer: Timer?

    init(
        makeChecker: @escaping () -> GitHubReleaseChecker? = { GitHubReleaseChecker() },
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) },
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.makeChecker = makeChecker
        self.openURL = openURL
        self.defaults = defaults
        self.now = now
        automaticChecksEnabled = ReleaseCheckSchedule.automaticChecksEnabled(using: defaults)
    }

    /// Checks shortly after launch, then re-evaluates hourly so a check still happens
    /// roughly once a day even if the Mac was asleep when it would have been due.
    func startAutomaticChecks() {
        pollTimer?.invalidate()

        DispatchQueue.main.asyncAfter(deadline: .now() + ReleaseCheckSchedule.launchDelay) { [weak self] in
            self?.checkAutomaticallyIfDue()
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: ReleaseCheckSchedule.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAutomaticallyIfDue()
            }
        }
    }

    func setAutomaticChecksEnabled(_ enabled: Bool) {
        automaticChecksEnabled = enabled
        defaults.set(enabled, forKey: ReleaseCheckSchedule.automaticChecksEnabledKey)

        if enabled {
            checkAutomaticallyIfDue()
        }
    }

    func toggleAutomaticChecks() {
        setAutomaticChecksEnabled(!automaticChecksEnabled)
    }

    func checkAutomaticallyIfDue() {
        guard automaticChecksEnabled, !isChecking else { return }

        let lastCheck = defaults.object(forKey: ReleaseCheckSchedule.lastCheckDateKey) as? Date
        guard ReleaseCheckSchedule.isCheckDue(lastCheck: lastCheck, now: now()) else { return }
        guard let checker = makeChecker() else { return }

        isChecking = true

        Task {
            defer { isChecking = false }

            // Automatic checks stay silent on failure and retry on the next poll.
            guard let outcome = try? await checker.checkForUpdates() else { return }
            defaults.set(now(), forKey: ReleaseCheckSchedule.lastCheckDateKey)

            if case .updateAvailable(let currentVersion, let latestVersion, let releasePage) = outcome,
               ReleaseCheckSchedule.shouldNotify(
                   latestVersion: latestVersion,
                   skippedVersion: defaults.string(forKey: ReleaseCheckSchedule.skippedVersionKey)
               ) {
                presentUpdate(currentVersion: currentVersion, latestVersion: latestVersion, releasePage: releasePage, allowSkip: true)
            }
        }
    }

    func checkForUpdates() {
        guard !isChecking else { return }
        guard let checker = makeChecker() else {
            presentError(ReleaseCheckError.invalidCurrentVersion)
            return
        }

        isChecking = true

        Task {
            defer { isChecking = false }

            do {
                let outcome = try await checker.checkForUpdates()
                defaults.set(now(), forKey: ReleaseCheckSchedule.lastCheckDateKey)
                present(outcome)
            } catch {
                presentError(error)
            }
        }
    }

    private func present(_ outcome: ReleaseCheckOutcome) {
        switch outcome {
        case .updateAvailable(let currentVersion, let latestVersion, let releasePage):
            presentUpdate(currentVersion: currentVersion, latestVersion: latestVersion, releasePage: releasePage, allowSkip: false)

        case .upToDate(let currentVersion):
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "You’re up to date"
            alert.informativeText = "CastSnip \(currentVersion) is the latest release on GitHub."
            alert.addButton(withTitle: "OK")
            _ = run(alert)
        }
    }

    private func presentUpdate(currentVersion: String, latestVersion: String, releasePage: URL, allowSkip: Bool) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "CastSnip \(latestVersion) is available"
        alert.informativeText = "You’re currently running \(currentVersion). Open the GitHub release page to download the latest version?"
        alert.addButton(withTitle: "Open Release Page")
        alert.addButton(withTitle: "Not Now")
        if allowSkip {
            alert.addButton(withTitle: "Skip This Version")
        }

        switch run(alert) {
        case .alertFirstButtonReturn:
            openURL(releasePage)
        case .alertThirdButtonReturn:
            defaults.set(latestVersion, forKey: ReleaseCheckSchedule.skippedVersionKey)
        default:
            break
        }
    }

    private func presentError(_ error: Error) {
        let nsError = error as NSError
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Unable to Check for Updates"
        alert.informativeText = nsError.localizedDescription
        alert.addButton(withTitle: "OK")
        _ = run(alert)
    }

    private func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApplication.shared.activate(ignoringOtherApps: true)
        return alert.runModal()
    }
}
