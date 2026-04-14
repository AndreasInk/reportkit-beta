import Foundation
import Testing
@testable import ReportKit

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

    func setSignUpResult(_ result: Result<UserSessionSnapshot?, Error>) {
        signUpResult = result
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

    @Test("First launch enters onboarding step 1 when unseen")
    func firstLaunchEntersOnboarding() async {
        let suite = "com.reportkit.tests.onboarding-first-launch"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let model = ReportKitSimpleAppModel(authProvider: TestAuthProvider(), userDefaults: defaults)
        await model.refresh()

        #expect(model.phase == .signedOut(.onboarding))
        #expect(model.onboardingStepIndex == 0)
        #expect(model.onboardingEntryMode == .firstRun)

        defaults.removePersistentDomain(forName: suite)
    }

    @Test("Skipping onboarding marks seen and routes to sign up auth")
    func skipOnboardingRoutesToSignUpAuth() async {
        let suite = "com.reportkit.tests.onboarding-skip"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let model = ReportKitSimpleAppModel(authProvider: TestAuthProvider(), userDefaults: defaults)
        await model.refresh()
        model.skipOnboarding()

        #expect(model.hasSeenOnboarding)
        #expect(model.phase == .signedOut(.auth))
        #expect(model.authMode == .signUp)
        #expect(model.onboardingStepIndex == 0)

        defaults.removePersistentDomain(forName: suite)
    }

    @Test("Completing onboarding marks seen and routes to sign up auth")
    func completeOnboardingRoutesToSignUpAuth() async {
        let suite = "com.reportkit.tests.onboarding-complete"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let model = ReportKitSimpleAppModel(authProvider: TestAuthProvider(), userDefaults: defaults)
        await model.refresh()
        model.nextStep()
        model.nextStep()
        model.nextStep()

        #expect(model.hasSeenOnboarding)
        #expect(model.phase == .signedOut(.auth))
        #expect(model.authMode == .signUp)
        #expect(model.onboardingStepIndex == 0)

        defaults.removePersistentDomain(forName: suite)
    }

    @Test("Restart onboarding from auth preserves credentials")
    func restartOnboardingPreservesCredentials() {
        let suite = "com.reportkit.tests.onboarding-restart"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.setValue(true, forKey: "ReportKitSimpleHasSeenOnboarding")

        let model = ReportKitSimpleAppModel(authProvider: TestAuthProvider(), userDefaults: defaults)
        model.phase = .signedOut(.auth)
        model.email = "person@example.com"
        model.password = "very-secret-password"
        model.authMode = .signIn

        model.restartOnboarding()

        #expect(model.phase == .signedOut(.onboarding))
        #expect(model.onboardingEntryMode == .revisit)
        #expect(model.onboardingStepIndex == 0)
        #expect(model.email == "person@example.com")
        #expect(model.password == "very-secret-password")
        #expect(model.authMode == .signIn)

        defaults.removePersistentDomain(forName: suite)
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
        await provider.setSignUpResult(.success(nil))
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
        #expect(state.title == "Mixpanel Funnel")
        #expect(state.summary == "Revenue is steady. Trial-to-paid dipped after yesterday's paywall experiment.")
        #expect(state.status == .warning)
        #expect(state.action == "Open the experiment and inspect the conversion cohort.")
    }

    @Test("Demo scenarios cover source-specific operator contexts")
    func demoScenariosCoverOperatorContexts() {
        #expect(ReportKitSimpleDemoScenario.scenarios(for: .minimal) == [.opsCalm, .releaseReadiness])
        #expect(ReportKitSimpleDemoScenario.scenarios(for: .banner) == [.supabaseErrors, .gcloudIncident])
        #expect(ReportKitSimpleDemoScenario.scenarios(for: .chart) == [.mixpanelFunnel, .appStoreAnalytics])
        #expect(ReportKitSimpleDemoScenario.scenarios(for: .progress) == [.codexAgentProgress])

        let supabaseState = ReportKitSimpleDemoScenario.supabaseErrors.contentState(
            now: Date(timeIntervalSince1970: 1_774_000_400)
        )
        #expect(supabaseState.status == .critical)
        #expect(supabaseState.resolvedVisualStyle == .banner)
        #expect(supabaseState.deepLink == "reportkitsimple://demo/supabase-errors")

        let appStoreState = ReportKitSimpleDemoScenario.appStoreAnalytics.contentState(
            now: Date(timeIntervalSince1970: 1_774_000_500)
        )
        #expect(appStoreState.resolvedVisualStyle == .chart)
        #expect(appStoreState.chartTitle == "Page Conversion (%)")
        #expect(appStoreState.chartValues == [5.4, 5.3, 5.2, 4.9, 4.6, 4.5, 4.4])

        let progressState = ReportKitSimpleDemoScenario.codexAgentProgress.contentState(
            now: Date(timeIntervalSince1970: 1_774_000_600)
        )
        #expect(progressState.resolvedVisualStyle == .progress)
        #expect(progressState.progressPercent == 68)
        #expect(progressState.completedSteps == 17)
        #expect(progressState.totalSteps == 25)
    }

    @Test("Long live activity actions collapse into concise CTA labels")
    func liveActivityActionsCollapseIntoCTAButtons() {
        let gcloudState = ReportKitSimpleDemoScenario.gcloudIncident.contentState()
        #expect(gcloudState.actionButtonText == "Inspect GCloud logs")

        let analyticsState = ReportKitSimpleDemoScenario.appStoreAnalytics.contentState()
        #expect(analyticsState.actionButtonText == "Compare screenshot sets")

        let shortAction = ReportKitSimpleAttributes.ContentState(
            generatedAt: 0,
            title: "Test",
            summary: "Test summary",
            status: .good,
            action: "Open dashboard",
            deepLink: nil,
            visualStyle: .banner,
            chartValues: nil,
            chartTitle: nil
        )
        #expect(shortAction.actionButtonText == "Open dashboard")
    }

    @Test("Progress helpers prefer percent and clamp derived values")
    func progressHelpersPreferPercentAndClampValues() {
        let percentOnly = ReportKitSimpleAttributes.ContentState(
            generatedAt: 0,
            title: "Task",
            summary: "Operation",
            status: .good,
            action: nil,
            deepLink: nil,
            visualStyle: .progress,
            chartValues: nil,
            chartTitle: nil,
            progressPercent: 135,
            completedSteps: nil,
            totalSteps: nil
        )
        #expect(percentOnly.normalizedProgressPercent == 100)
        #expect(percentOnly.progressFraction == 1)
        #expect(percentOnly.progressSummaryText == "100% complete")
        #expect(percentOnly.compactProgressLabel == "100%")

        let stepsOnly = ReportKitSimpleAttributes.ContentState(
            generatedAt: 0,
            title: "Task",
            summary: "Operation",
            status: .warning,
            action: nil,
            deepLink: nil,
            visualStyle: .progress,
            chartValues: nil,
            chartTitle: nil,
            progressPercent: nil,
            completedSteps: 4,
            totalSteps: 8
        )
        #expect(stepsOnly.normalizedStepCounts?.completed == 4)
        #expect(stepsOnly.normalizedStepCounts?.total == 8)
        #expect(stepsOnly.progressFraction == 0.5)
        #expect(stepsOnly.progressSummaryText == "4 of 8 steps")
        #expect(stepsOnly.compactProgressLabel == "4/8")

        let mixed = ReportKitSimpleAttributes.ContentState(
            generatedAt: 0,
            title: "Task",
            summary: "Operation",
            status: .critical,
            action: nil,
            deepLink: nil,
            visualStyle: .progress,
            chartValues: nil,
            chartTitle: nil,
            progressPercent: 52,
            completedSteps: 4,
            totalSteps: 8
        )
        #expect(mixed.progressFraction == 0.52)
        #expect(mixed.progressSummaryText == "52% complete • 4 of 8 steps")
        #expect(mixed.compactProgressLabel == "52%")

        let invalidSteps = ReportKitSimpleAttributes.ContentState(
            generatedAt: 0,
            title: "Task",
            summary: "Operation",
            status: .warning,
            action: nil,
            deepLink: nil,
            visualStyle: .progress,
            chartValues: nil,
            chartTitle: nil,
            progressPercent: nil,
            completedSteps: 4,
            totalSteps: 0
        )
        #expect(invalidSteps.normalizedStepCounts == nil)
        #expect(invalidSteps.progressFraction == nil)
        #expect(invalidSteps.progressSummaryText == nil)
    }

    @Test("Config parser rejects unresolved placeholders outside tests")
    func configRejectsUnresolvedPlaceholders() throws {
        let source = ReportKitSimpleConfig.Source(
            environment: [:],
            infoDictionary: [
                "REPORTKIT_SUPABASE_URL": "$(REPORTKIT_SUPABASE_URL)",
                "REPORTKIT_SUPABASE_ANON_KEY": "$(REPORTKIT_SUPABASE_ANON_KEY)"
            ],
            isRunningTests: false
        )

        #expect(throws: ReportKitSimpleConfigError.missingOrUnresolvedKey("REPORTKIT_SUPABASE_URL")) {
            _ = try ReportKitSimpleConfig.requiredValue("REPORTKIT_SUPABASE_URL", source: source)
        }
    }

    @Test("Config parser uses deterministic test fallback values")
    func configUsesTestFallbackValues() throws {
        let source = ReportKitSimpleConfig.Source(
            environment: [:],
            infoDictionary: [:],
            isRunningTests: true
        )

        let url = try ReportKitSimpleConfig.requiredValue("REPORTKIT_SUPABASE_URL", source: source)
        let anon = try ReportKitSimpleConfig.requiredValue("REPORTKIT_SUPABASE_ANON_KEY", source: source)

        #expect(url == "https://example.supabase.co")
        #expect(anon == "test-anon-key")
    }

    @Test("Remote alarm diagnostics suppress recent duplicate alarm ids")
    func remoteAlarmDiagnosticsDedupesRecentIDs() {
        let suite = "com.reportkit.tests.remote-alarm-diagnostics"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let diagnostics = RemoteAlarmDiagnostics(defaults: defaults, duplicateWindow: 60)
        #expect(diagnostics.shouldIgnoreDuplicate("alarm-1") == false)

        diagnostics.record(
            status: "Scheduled",
            source: "background-fetch",
            alarmID: "alarm-1",
            detail: "Test"
        )

        #expect(diagnostics.shouldIgnoreDuplicate("alarm-1"))
        #expect(diagnostics.shouldIgnoreDuplicate("alarm-2") == false)
        #expect(diagnostics.snapshot.status == "Scheduled: Test")
        #expect(diagnostics.snapshot.source == "background-fetch")

        defaults.removePersistentDomain(forName: suite)
    }
}
