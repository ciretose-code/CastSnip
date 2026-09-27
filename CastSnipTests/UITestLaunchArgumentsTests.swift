import Testing
import Foundation
@testable import CastSnip

struct UITestLaunchArgumentsTests {

    @Test func parsesOpenSampleToken() {
        let args = UITestLaunchArguments(arguments: ["CastSnip", "-UITestOpen", "sample"])
        #expect(args.openSource == .sample)
        #expect(args.isActive)
    }

    @Test func parsesOpenFilePath() {
        let args = UITestLaunchArguments(arguments: ["CastSnip", "-UITestOpen", "/tmp/episode.mp3"])
        #expect(args.openSource == .file(URL(fileURLWithPath: "/tmp/episode.mp3")))
    }

    @Test func parsesSaveAsAndEncodeDestinations() {
        let args = UITestLaunchArguments(arguments: [
            "CastSnip",
            "-UITestSaveAs", "/tmp/saved.mp3",
            "-UITestEncode", "/tmp/encoded.mp3"
        ])
        #expect(args.saveAsURL?.path == "/tmp/saved.mp3")
        #expect(args.encodeURL?.path == "/tmp/encoded.mp3")
        #expect(args.isActive)
    }

    @Test func ignoresFlagsWithoutValues() {
        let args = UITestLaunchArguments(arguments: ["CastSnip", "-UITestOpen", "-UITestSaveAs"])
        #expect(args.openSource == nil)
        #expect(args.saveAsURL == nil)
        #expect(!args.isActive)
    }

    @Test func emptyWhenNoUITestFlags() {
        let args = UITestLaunchArguments(arguments: ["CastSnip"])
        #expect(!args.isActive)
        #expect(args.openSource == nil)
        #expect(args.saveAsURL == nil)
        #expect(args.encodeURL == nil)
    }

    @Test func resolvesSampleToBundledIntro() {
        let args = UITestLaunchArguments(arguments: ["CastSnip", "-UITestOpen", "sample"])
        let url = args.resolvedOpenURL(in: Bundle(for: AudioFile.self))
        #expect(url?.lastPathComponent == "intro.mp3")
    }

    @Test func relativeDestinationUsesTemporaryDirectory() {
        let args = UITestLaunchArguments(arguments: ["CastSnip", "-UITestSaveAs", "saved.mp3"])
        #expect(args.saveAsURL?.lastPathComponent == "saved.mp3")
        #expect(args.saveAsURL?.path.hasPrefix("/") == true)
        #expect(args.saveAsURL?.path.hasSuffix("/saved.mp3") == true)
        #expect(args.saveAsURL?.path != "/saved.mp3")
    }
}
