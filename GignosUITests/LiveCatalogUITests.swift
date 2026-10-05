import XCTest

@MainActor
final class LiveCatalogUITests: XCTestCase {
    func testLiveTabsSearchDetailAndSavedPersistence() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["GIGNOS_UI_TEST_DEFAULTS"] = "GignosUITests.\(UUID().uuidString)"
        app.launch()

        let sections = [("Sites", "sites"), ("Classifications", "classifications"), ("Time periods", "time_periods"), ("Cultures", "cultures"), ("Sources", "sources")]
        for (label, key) in sections {
            let tab = app.tabBars.buttons[label]
            XCTAssertTrue(tab.waitForExistence(timeout: 10), "Missing website tab: \(label)")
            tab.tap()
            XCTAssertTrue(app.staticTexts["catalog-ready-\(key)"].waitForExistence(timeout: 90), "Live \(label) catalog failed to load")
            capture(app, name: label)
        }

        app.tabBars.buttons["Sites"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Laetoli Site G")
        let site = app.buttons["record-sites/laetoli-site-g"]
        XCTAssertTrue(site.waitForExistence(timeout: 10), "Search should find a site beyond the first API page")
        site.tap()
        XCTAssertTrue(app.navigationBars["Laetoli Site G"].waitForExistence(timeout: 10))
        let save = app.buttons["save-record"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        XCTAssertEqual(save.label, "Save record")
        save.tap()
        XCTAssertEqual(save.label, "Remove from saved")
        capture(app, name: "Live site detail")

        // Relaunch with the same isolated defaults: this checks actual disk persistence.
        app.terminate()
        app.launch()
        let saved = app.buttons["Saved records"]
        XCTAssertTrue(saved.waitForExistence(timeout: 10))
        saved.tap()
        let savedSite = app.buttons["saved-sites/laetoli-site-g"]
        XCTAssertTrue(savedSite.waitForExistence(timeout: 10))
        savedSite.tap()
        XCTAssertTrue(app.navigationBars["Laetoli Site G"].waitForExistence(timeout: 10))
        app.buttons["save-record"].tap()
        XCTAssertEqual(app.buttons["save-record"].label, "Save record")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Your next discoveries"].waitForExistence(timeout: 10))
        capture(app, name: "Saved records empty state")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
