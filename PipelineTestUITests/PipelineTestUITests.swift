import XCTest

/// UI-Tests auf iPhone- und iPad-Simulator. Screenshots werden als XCTAttachment
/// gespeichert und im Workflow aus dem .xcresult exportiert.
final class PipelineTestUITests: XCTestCase {
    private var idiom: String { UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    @discardableResult
    private func launch(reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + (reset ? ["-resetData"] : []) + extra
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(idiom)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func field(_ app: XCUIApplication) -> XCUIElement {
        let f = app.textFields["noteField"]
        XCTAssertTrue(f.waitForExistence(timeout: 15), "Eingabefeld nicht gefunden")
        return f
    }

    private func addNote(_ app: XCUIApplication, _ text: String) {
        let f = field(app)
        f.tap()
        f.typeText(text)
        app.buttons["addButton"].tap()
        XCTAssertTrue(app.staticTexts[text].firstMatch.waitForExistence(timeout: 5), "Notiz '\(text)' fehlt in der Liste")
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while !element.exists && tries < 8 {
            app.swipeUp()
            tries += 1
        }
    }

    func test01_LayoutMatchesDeviceClass() {
        let app = launch()
        _ = field(app)
        let info = app.staticTexts["layoutInfo"]
        reveal(info, in: app)
        XCTAssertTrue(info.waitForExistence(timeout: 5))
        let expected = idiom == "ipad" ? "Layout: split" : "Layout: stack"
        XCTAssertTrue(info.label.contains(expected), "Erwartet \(expected), gefunden: \(info.label)")
        XCTAssertTrue(info.label.contains("Schrift: normal"))
        shot(app, "01-start-hochformat")
    }

    func test02_KeyboardInputAndNavigation() {
        let app = launch()
        let f = field(app)
        f.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), "Bildschirmtastatur nicht sichtbar")
        f.typeText("Einkauf Milch")
        shot(app, "02-tastatur")
        app.buttons["addButton"].tap()

        let row = app.staticTexts["Einkauf Milch"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let detail = app.staticTexts["detailText"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "Detailansicht nicht geöffnet")
        XCTAssertEqual(detail.label, "Einkauf Milch")
        shot(app, "02-detail")

        if idiom == "iphone" {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.textFields["noteField"].waitForExistence(timeout: 5), "Zurück-Navigation fehlgeschlagen")
        }
    }

    func test03_EmptyInputShowsError() {
        let app = launch()
        _ = field(app)
        app.buttons["addButton"].tap()
        let error = app.staticTexts["errorLabel"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.contains("Bitte Text eingeben"))
        shot(app, "03-fehler-leere-eingabe")
    }

    func test04_DataRestoredAfterRelaunch() {
        let app = launch(reset: true)
        addNote(app, "Persistenz-Test")
        app.terminate()

        let relaunched = launch(reset: false)
        _ = field(relaunched)
        XCTAssertTrue(relaunched.staticTexts["Persistenz-Test"].firstMatch.waitForExistence(timeout: 10),
                      "Notiz nach Neustart nicht wiederhergestellt")
        shot(relaunched, "04-nach-neustart")
    }

    func test05_LargeDynamicType() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"])
        let f = field(app)
        shot(app, "05-grosse-schrift")
        f.tap()
        f.typeText("Groß")
        app.buttons["addButton"].tap()
        XCTAssertTrue(app.staticTexts["Groß"].firstMatch.waitForExistence(timeout: 5))
        let info = app.staticTexts["layoutInfo"]
        reveal(info, in: app)
        XCTAssertTrue(info.waitForExistence(timeout: 5))
        XCTAssertTrue(info.label.contains("Schrift: groß"), "Große Schrift nicht aktiv: \(info.label)")
        shot(app, "05-grosse-schrift-unten")
    }

    func test06_LandscapeLayout() {
        let app = launch()
        _ = field(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        let window = app.windows.firstMatch
        let predicate = NSPredicate { _, _ in window.frame.width > window.frame.height }
        let exp = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: 10), .completed, "Querformat nicht übernommen: \(window.frame)")
        addNote(app, "Querformat")
        shot(app, "06-querformat")
    }

    func test07_FreeLimitShowsProHint() {
        let app = launch()
        for i in 1...3 { addNote(app, "Gratis \(i)") }
        let f = field(app)
        f.tap()
        f.typeText("Vierte")
        app.buttons["addButton"].tap()
        let error = app.staticTexts["errorLabel"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.contains("Gratis-Version"), error.label)
        shot(app, "07-gratis-limit")
    }
}
