import XCTest

final class PairingUITests: XCTestCase {
    @MainActor
    func testURLOnlySubmissionExplainsMissingCode() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertFalse(app.alerts["Connection issue"].exists, "Unexpected startup error: \(app.alerts.debugDescription)")
        let server = app.textFields["Server URL"]
        XCTAssertTrue(server.waitForExistence(timeout: 10))
        server.tap()
        server.typeText("https://example.com")
        app.buttons["Pair securely"].tap()
        let alert = app.alerts["Connection issue"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "access code")).firstMatch.exists)
        alert.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["Pair securely"].isEnabled)
        XCTAssertEqual(server.value as? String, "https://example.com")
    }

    @MainActor
    func testAccessibilityTextAndLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        XCTAssertFalse(app.alerts["Connection issue"].exists, "Unexpected startup error: \(app.alerts.debugDescription)")
        XCTAssertTrue(app.textFields["Server URL"].waitForExistence(timeout: 10))
        let pair = app.buttons["Pair securely"]
        for _ in 0..<6 {
            if pair.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(pair.isHittable)
        pair.tap()
        XCTAssertTrue(app.alerts["Connection issue"].waitForExistence(timeout: 5))
        app.alerts["Connection issue"].buttons["OK"].tap()
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Landscape accessibility text"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
