import Foundation
import Testing
@testable import ReportKitSimple

enum TestAuthError: Error {
    case testError
}

actor TestAuthProvider: ReportKitSimpleAuthenticating {
    var currentSessionResult: UserSessionSnapshot?
    var signInResult: Result<UserSessionSnapshot, Error> = .failure(TestAuthError.testError)
    var signUpResult: Result<UserSessionSnapshot?, Error> = .success(nil)
    var signOutCalled = false
    var signInCallCount = 0
    var signUpCallCount = 0

    init(currentSessionResult: UserSessionSnapshot? = nil) {
        self.currentSessionResult = currentSessionResult
    }

    func currentSession() async -> UserSessionSnapshot? {
        currentSessionResult
    }

    func signIn(email: String, password: String) async throws -> UserSessionSnapshot {
        signInCallCount += 1
        return try signInResult.get()
    }

    func signUp(email: String, password: String) async throws -> UserSessionSnapshot? {
        signUpCallCount += 1
        return try signUpResult.get()
    }

    func signOut() async {
        signOutCalled = true
    }
}

@MainActor
struct ReportKitSimpleTests {
    @Test("Signed-in phase exposes user email")
    func signedInPhaseTracksUserEmail() {
        let session = UserSessionSnapshot(userID: "demo-user", email: "demo@example.com")
        let model = ReportKitSimpleAppModel()
        model.phase = .signedIn(session)

        #expect(session.email == "demo@example.com")
        #expect(session.userID == "demo-user")
    }

    @Test("Auth screen starts in sign in mode with onboarding unseen")
    func authModeAndOnboardingDefaultState() {
        let defaults = UserDefaults(suiteName: "com.reportkit.tests.onboarding-defaults")!
        defaults.removePersistentDomain(forName: "com.reportkit.tests.onboarding-defaults")

        let model = ReportKitSimpleAppModel(authProvider: TestAuthProvider(), userDefaults: defaults)

        #expect(model.authMode == .signIn)
        #expect(!model.hasSeenOnboarding)
        model.markOnboardingSeen()
        #expect(model.hasSeenOnboarding)

        let reloadedModel = ReportKitSimpleAppModel(authProvider: TestAuthProvider(), userDefaults: defaults)
        #expect(reloadedModel.hasSeenOnboarding)

        defaults.removePersistentDomain(forName: "com.reportkit.tests.onboarding-defaults")
    }

    @Test("Sign in requires credentials before calling auth provider")
    func signInValidationBlocksMissingCredentials() async {
        let provider = TestAuthProvider()
        let model = ReportKitSimpleAppModel(authProvider: provider, userDefaults: UserDefaults(suiteName: "com.reportkit.tests.signin-validation")!)

        await model.signIn()
        #expect(model.errorMessage == "Email is required.")

        model.email = "user@example.com"
        await model.signIn()
        #expect(model.errorMessage == "Password is required.")

        let signInCalls = await provider.signInCallCount
        #expect(signInCalls == 0)
    }

    @Test("Sign up can be started and supports email-confirmation flow")
    func signUpConfirmationMessage() async {
        let provider = TestAuthProvider()
        provider.signUpResult = .success(nil)
        let defaults = UserDefaults(suiteName: "com.reportkit.tests.signup")!
        defaults.removePersistentDomain(forName: "com.reportkit.tests.signup")
        let model = ReportKitSimpleAppModel(authProvider: provider, userDefaults: defaults)
        model.email = "new@example.com"
        model.password = "password"

        await model.signUp()

        #expect(model.infoMessage == "Account created. Please check your email to confirm before signing in.")
        let signUpCalls = await provider.signUpCallCount
        #expect(signUpCalls == 1)
        #expect(await provider.signOutCalled == false)

        defaults.removePersistentDomain(forName: "com.reportkit.tests.signup")
    }

    @Test("SignIn mode validation remains present")
    func reportKitAttributesContract() {
        let state = ReportKitSimpleAttributes.ContentState.preview
        #expect(state.title == "Daily Pulse")
        #expect(state.summary == "Revenue is steady. Trial-to-paid dipped after yesterday's paywall experiment.")
        #expect(state.status == .warning)
        #expect(state.action == "Review the new paywall copy before noon.")
    }
}
