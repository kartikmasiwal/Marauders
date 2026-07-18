import XCTest

final class MaraudersUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGoogleDemoLoginOpensTours() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["googleSignInButton"].tap()
        let toursTab = app.tabBars.buttons["My Tours"]
        XCTAssertTrue(toursTab.waitForExistence(timeout: 5))
        toursTab.tap()
        XCTAssertTrue(app.staticTexts["My Tours"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["viewTicket_taj-mahal"].exists)
    }

    func testBundledTourReachesMap() {
        let app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Location permission") { alert in
            let allow = alert.buttons["Allow While Using App"]
            if allow.exists { allow.tap(); return true }
            return false
        }
        app.launch()
        app.buttons["googleSignInButton"].tap()
        let toursTab = app.tabBars.buttons["My Tours"]
        XCTAssertTrue(toursTab.waitForExistence(timeout: 5))
        toursTab.tap()
        let prepare = app.buttons["viewTicket_taj-mahal"]
        XCTAssertTrue(prepare.waitForExistence(timeout: 5))
        prepare.tap()
        let ready = app.staticTexts["Tour ready offline"]
        if !ready.waitForExistence(timeout: 2), prepare.exists {
            prepare.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(ready.waitForExistence(timeout: 10))
        app.buttons["startTourButton"].tap()
        app.tap()
        XCTAssertTrue(app.buttons["checkpoint_cp_great_gate"].waitForExistence(timeout: 5))
        let browse = app.buttons["browseCheckpointButton"]
        XCTAssertTrue(browse.waitForExistence(timeout: 5))
        browse.tap()
        if !app.navigationBars["Browse Secrets"].waitForExistence(timeout: 2) { browse.tap() }
        XCTAssertTrue(app.navigationBars["Browse Secrets"].waitForExistence(timeout: 5))
        app.buttons["browseNugget_n_gate_illusion"].tap()
        XCTAssertTrue(app.staticTexts["nuggetRevealTitle_n_gate_illusion"].waitForExistence(timeout: 5))
        app.buttons["closeNuggetReveal"].tap()
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["1/2 SECRETS"].waitForExistence(timeout: 5))
    }
}
