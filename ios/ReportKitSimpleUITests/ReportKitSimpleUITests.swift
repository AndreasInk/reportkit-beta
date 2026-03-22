import XCTest

@MainActor
final class ReportKitSimpleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func appForFreshOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-ReportKitSimpleResetOnboarding")
        app.launchEnvironment["REPORTKIT_SUPABASE_URL"] = "https://example.supabase.co"
        app.launchEnvironment["REPORTKIT_SUPABASE_ANON_KEY"] = "test-anon-key"
        return app
    }

    func testFirstLaunchShowsOnboardingPagerControls() throws {
        let app = appForFreshOnboarding()
        app.launch()

        XCTAssertTrue(app.staticTexts["onboarding-step-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["onboarding-step-indicator"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["onboarding-skip-button"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["onboarding-next-button"].waitForExistence(timeout: 2))
    }

    func testContinueThroughOnboardingLandsInSignUp() throws {
        let app = appForFreshOnboarding()
        app.launch()

        let continueButton = app.buttons["onboarding-next-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))

        continueButton.tap()
        continueButton.tap()
        continueButton.tap()

        XCTAssertTrue(app.buttons["sign-up-button"].waitForExistence(timeout: 2))
    }

    func testSkipFromStepOneLandsInSignUp() throws {
        let app = appForFreshOnboarding()
        app.launch()

        let skipButton = app.buttons["onboarding-skip-button"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.tap()

        XCTAssertTrue(app.buttons["sign-up-button"].waitForExistence(timeout: 2))
    }

    func testViewIntroAgainReturnsToOnboarding() throws {
        let app = appForFreshOnboarding()
        app.launch()

        let skipButton = app.buttons["onboarding-skip-button"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.tap()
        XCTAssertTrue(app.buttons["sign-up-button"].waitForExistence(timeout: 2))

        let introAgainButton = app.buttons["view-intro-again-button"]
        XCTAssertTrue(introAgainButton.waitForExistence(timeout: 2))
        introAgainButton.tap()

        XCTAssertTrue(app.staticTexts["onboarding-step-title"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["onboarding-next-button"].waitForExistence(timeout: 2))
    }
}
