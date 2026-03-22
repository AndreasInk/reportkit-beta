import XCTest

final class ReportKitSimpleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func appForFreshOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-ReportKitSimpleResetOnboarding")
        return app
    }

    func testOnboardingTextVisibleOnFirstLaunch() throws {
        let app = appForFreshOnboarding()
        app.launch()

        let onboardingTitle = app.staticTexts["onboarding-title"]
        XCTAssertTrue(onboardingTitle.waitForExistence(timeout: 5))
    }

    func testAuthModeCanSwitchToSignUp() throws {
        let app = appForFreshOnboarding()
        app.launch()

        let signUpSegment = app.segmentedControls["auth-mode-toggle"].buttons["Sign Up"]
        XCTAssertTrue(signUpSegment.waitForExistence(timeout: 5))
        signUpSegment.tap()

        XCTAssertTrue(app.buttons["sign-up-button"].waitForExistence(timeout: 2))
    }

    func testSignInButtonIsVisible() throws {
        let app = appForFreshOnboarding()
        app.launch()

        let signInButton = app.buttons["sign-in-button"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
    }

    func testAuthFieldsRemainOnSignInMode() throws {
        let app = appForFreshOnboarding()
        app.launch()

        XCTAssertTrue(app.textFields["auth-email-field"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["auth-password-field"].waitForExistence(timeout: 2))
    }
}
