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
}
