import XCTest

/// Accessibility identifiers must stay in sync with `EditorAccessibility`.
private enum EditorA11y {
    static let podcastTitle = "Podcast title"
    static let play = "Play"
    static let playPause = "PlayPause"
    static let emptyEditor = "Empty editor"
    static let encoding = "Encoding"
}

final class ForecastLoopUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
        try super.tearDownWithError()
    }

    func testOpensFixtureAudioFile() {
        let app = launchApp(openSample: true)

        XCTAssertTrue(titleField(in: app).waitForExistence(timeout: 15))
        XCTAssertTrue(playControl(in: app).exists)
        XCTAssertFalse(app.descendants(matching: .any)[EditorA11y.emptyEditor].exists)
    }

    func testEditsTitleAndSaveAsWritesFile() {
        let filename = "uitest-saved-\(UUID().uuidString).mp3"
        let app = launchApp(openSample: true, saveAs: filename)

        let title = titleField(in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        title.click()
        title.typeKey("a", modifierFlags: .command)
        title.typeText("UI Test Show")

        chooseFileMenuItem(app, named: "Save As...")

        XCTAssertTrue(
            windowNamed(filename, in: app).waitForExistence(timeout: 15),
            "Save As should update the window title after writing \(filename)"
        )
        XCTAssertEqual(title.value as? String, "UI Test Show")
    }

    func testEncodeReachesCompletionWithoutHanging() {
        let filename = "uitest-encoded-\(UUID().uuidString).mp3"
        let app = launchApp(openSample: true, encode: filename)

        XCTAssertTrue(playControl(in: app).waitForExistence(timeout: 15))
        chooseFileMenuItem(app, named: "Encode to MP3…")

        let encoding = app.descendants(matching: .any)[EditorA11y.encoding]
        let destWindow = windowNamed(filename, in: app)
        let reachedEncode = encoding.waitForExistence(timeout: 10) || destWindow.exists
        XCTAssertTrue(reachedEncode, "Encode should start without hanging on a save panel")

        waitUntil(timeout: 60) {
            destWindow.exists || !encoding.exists
        }
        XCTAssertTrue(
            destWindow.exists || !encoding.exists,
            "Encode should finish or dismiss its progress UI without hanging"
        )
    }

    private func launchApp(openSample: Bool, saveAs: String? = nil, encode: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments: [String] = []
        if openSample {
            arguments += ["-UITestOpen", "sample"]
        }
        if let saveAs {
            arguments += ["-UITestSaveAs", saveAs]
        }
        if let encode {
            arguments += ["-UITestEncode", encode]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func titleField(in app: XCUIApplication) -> XCUIElement {
        let byIdentifier = app.textFields[EditorA11y.podcastTitle]
        if byIdentifier.exists { return byIdentifier }
        return app.textViews[EditorA11y.podcastTitle]
    }

    private func playControl(in app: XCUIApplication) -> XCUIElement {
        let byIdentifier = app.buttons[EditorA11y.playPause]
        if byIdentifier.waitForExistence(timeout: 15) { return byIdentifier }
        return app.buttons[EditorA11y.play]
    }

    private func windowNamed(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.windows[name]
    }

    private func chooseFileMenuItem(_ app: XCUIApplication, named name: String) {
        let fileMenu = app.menuBars.menuBarItems["File"]
        if fileMenu.exists {
            fileMenu.click()
        }
        let exact = app.menuBars.menuItems[name]
        if exact.exists {
            exact.click()
            return
        }
        let ascii = app.menuBars.menuItems[name.replacingOccurrences(of: "…", with: "...")]
        if ascii.exists {
            ascii.click()
            return
        }
        XCTFail("Missing File menu item \(name)")
    }

    private func waitUntil(timeout: TimeInterval, _ predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
    }
}
