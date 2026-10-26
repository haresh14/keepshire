import XCTest

/// Captures App Store screenshots. Skipped unless SCREENSHOT_DIR is set, which
/// release/screenshots.sh passes as TEST_RUNNER_SCREENSHOT_DIR. The script stages
/// the sample photos in the App Group share inbox before the test runs.
/// Screenshot Protection is turned off before capturing (it blanks captures) and
/// turned back on at the end.
final class AppStoreScreenshotTests: XCTestCase {
    private var outputDirectory: URL!
    private var prefix = ""

    override func setUpWithError() throws {
        guard let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !path.isEmpty else {
            throw XCTSkip("SCREENSHOT_DIR is not set")
        }
        outputDirectory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        prefix = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.buttons["keypad.1"].waitForExistence(timeout: 10))
        enter("1234", in: app)
        XCTAssertTrue(app.buttons["tab.folder"].firstMatch.waitForExistence(timeout: 10))

        // Screenshot protection blanks every capture, including XCUIScreen's.
        setProtection(false, in: app)

        waitForSampleImport(in: app)
        createFolders(["Travel", "Family", "Documents", "Receipts"], in: app)

        app.buttons["tab.gallery"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Gallery"].waitForExistence(timeout: 5))
        settle()
        capture("02-gallery")

        let firstItem = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'file.'"))
            .firstMatch
        XCTAssertTrue(firstItem.waitForExistence(timeout: 5))
        firstItem.tap()
        settle(2)
        capture("03-viewer")
        dismissViewer(in: app)

        app.buttons["tab.folder"].firstMatch.tap()
        settle()
        capture("04-folders")

        app.buttons["tab.category"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))
        settle()
        capture("05-categories")

        app.buttons["tab.webUpload"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Web Upload"].waitForExistence(timeout: 5))
        settle()
        capture("06-web-upload")

        app.buttons["tab.settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        settle()
        capture("07-settings")

        // Relaunch without --ui-testing so the vault, passcode, and settings persist.
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["keypad.1"].waitForExistence(timeout: 10))
        enter("12", in: app)
        capture("01-lock")
        enter("34", in: app)
        XCTAssertTrue(app.buttons["tab.folder"].firstMatch.waitForExistence(timeout: 10))

        setProtection(true, in: app)
    }

    /// Plays a slow, loopable tour for the app preview video. release/app-preview.sh
    /// records the simulator and cuts the video from the time written to
    /// preview-start.txt.
    @MainActor
    func testRecordAppPreview() throws {
        guard ProcessInfo.processInfo.environment["APP_PREVIEW"] == "1" else {
            throw XCTSkip("APP_PREVIEW is not set")
        }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["keypad.1"].waitForExistence(timeout: 10))
        enter("1234", in: app)
        XCTAssertTrue(app.buttons["tab.folder"].firstMatch.waitForExistence(timeout: 10))

        // Both protections black out captures; recording protection covers video.
        let captureToggles = ["settings.screenshotProtection", "settings.recordingProtection"]
        setProtection(false, toggles: captureToggles, in: app)
        waitForSampleImport(in: app)
        createFolders(["Travel", "Family", "Documents", "Receipts"], in: app)

        // Start the tour from a locked app.
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["keypad.1"].waitForExistence(timeout: 10))
        settle(1)
        let marker = outputDirectory.appendingPathComponent("preview-start.txt")
        try String(Date().timeIntervalSince1970).write(to: marker, atomically: true, encoding: .utf8)
        settle(1.5)
        "1234".forEach { digit in
            app.buttons["keypad.\(digit)"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            settle(0.3)
        }
        XCTAssertTrue(app.buttons["tab.gallery"].firstMatch.waitForExistence(timeout: 10))
        settle(1)

        // Each XCUITest action adds 1–2 s, so the tour keeps few steps to stay under 30 s.
        app.buttons["tab.gallery"].firstMatch.tap()
        settle(1.2)
        let items = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'file.'"))
        items.element(boundBy: min(5, items.count - 1)).tap()
        settle(1)
        app.swipeLeft()
        settle(1)
        dismissViewer(in: app)
        app.buttons["tab.webUpload"].firstMatch.tap()
        settle(1.5)
        app.buttons["tab.folder"].firstMatch.tap()
        settle(1.5)
        let end = outputDirectory.appendingPathComponent("preview-end.txt")
        try String(Date().timeIntervalSince1970).write(to: end, atomically: true, encoding: .utf8)
        settle(1)

        setProtection(true, toggles: captureToggles, in: app)
    }

    // MARK: - Steps

    @MainActor
    private func setProtection(
        _ enabled: Bool,
        toggles identifiers: [String] = ["settings.screenshotProtection"],
        in app: XCUIApplication
    ) {
        app.buttons["tab.settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        // On iPad, Settings is a split view and the toggles live under Security.
        let securityPane = app.collectionViews["Sidebar"].staticTexts["Security"]
        if securityPane.exists {
            securityPane.tap()
            settle()
        }
        for identifier in identifiers {
            let toggle = app.switches[identifier]
            for _ in 0..<5 where !(toggle.exists && toggle.isHittable) {
                app.swipeUp()
            }
            XCTAssertTrue(toggle.isHittable, app.debugDescription)
            if isOn(toggle) != enabled {
                // SwiftUI toggles only flip when the switch itself is tapped.
                toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
            }
            settle()
            XCTAssertEqual(isOn(toggle), enabled, "\(identifier) did not change")
        }
        for _ in 0..<5 {
            app.swipeDown()
        }
    }

    private func isOn(_ toggle: XCUIElement) -> Bool {
        (toggle.value as? String) == "1"
    }

    /// The script stages the photos in the App Group share inbox, which the app
    /// imports on unlock exactly like files sent from the Share extension.
    @MainActor
    private func waitForSampleImport(in app: XCUIApplication) {
        app.buttons["tab.gallery"].firstMatch.tap()
        let items = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'file.'"))
        let deadline = Date().addingTimeInterval(60)
        while items.count < 12 && Date() < deadline {
            settle(1)
        }
        XCTAssertGreaterThan(items.count, 0, "No staged photos were imported")
        settle(2)
    }

    @MainActor
    private func createFolders(_ names: [String], in app: XCUIApplication) {
        app.buttons["tab.folder"].firstMatch.tap()
        for name in names {
            app.buttons["folder.actions"].firstMatch.tap()
            app.buttons["Add Files"].tap()
            let create = app.buttons["add.create-folder"]
            XCTAssertTrue(create.waitForExistence(timeout: 5), app.debugDescription)
            create.tap()
            let field = app.alerts.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
            field.typeText(name)
            app.alerts.buttons["Create"].tap()
            settle(1)
        }
    }

    @MainActor
    private func dismissViewer(in app: XCUIApplication) {
        let close = app.buttons["Close preview"].firstMatch
        if close.exists {
            close.tap()
        } else {
            app.swipeDown()
        }
        settle()
    }

    // MARK: - Helpers

    @MainActor
    private func enter(_ digits: String, in app: XCUIApplication) {
        digits.forEach { digit in
            app.buttons["keypad.\(digit)"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            settle(0.2)
        }
    }

    private func settle(_ seconds: TimeInterval = 1) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    @MainActor
    private func capture(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let url = outputDirectory.appendingPathComponent("\(prefix)-\(name).png")
        XCTAssertNoThrow(try data.write(to: url))
    }
}
