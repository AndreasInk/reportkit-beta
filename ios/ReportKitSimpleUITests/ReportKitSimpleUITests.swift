import XCTest

final class ReportKitSimpleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSignInButtonIsVisible() throws {
        let app = XCUIApplication()
        app.launch()

        let signInButton = app.buttons["sign-in-button"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
    }
}
