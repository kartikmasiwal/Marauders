import XCTest

final class MaraudersUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGoogleDemoLoginOpensTours() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["googleSignInButton"].tap()
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
        let prepare = app.buttons["viewTicket_taj-mahal"]
        XCTAssertTrue(prepare.waitForExistence(timeout: 5))
        prepare.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Tour ready offline"].waitForExistence(timeout: 10))
        app.buttons["startTourButton"].tap()
        app.tap()
        XCTAssertTrue(app.buttons["checkpoint_cp_main_gate"].waitForExistence(timeout: 5))
    }
}
