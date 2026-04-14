import SwiftUI

struct ReportKitSimpleRootView: View {
    @EnvironmentObject private var model: ReportKitSimpleAppModel

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .launching:
                    ProgressView("Loading ReportKit")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .signedOut(let signedOutScreen):
                    switch signedOutScreen {
                    case .onboarding:
                        OnboardingPagerView()
                    case .auth:
                        AuthScreen()
                    }
                case .signedIn(let session):
                    SignedInScreen(session: session)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("ReportKit")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await model.refresh()
        }
    }
}

private struct OnboardingPage {
    let title: String
    let message: String
}

private struct OnboardingPagerView: View {
    @EnvironmentObject private var model: ReportKitSimpleAppModel

    private let pages = [
        OnboardingPage(
            title: "Noise steals attention.",
            message: "Important app signals get buried across chats, dashboards, and alerts. ReportKitSimple reduces that noise."
        ),
        OnboardingPage(
            title: "One lock-screen truth.",
            message: "Keep your Live Activity aligned with the latest report state so you can glance, assess, and act quickly."
        ),
        OnboardingPage(
            title: "Set up in minutes.",
            message: "Create your account, sign in on your CLI and phone with the same credentials, and your token sync starts."
        )
    ]

    var body: some View {
        let page = pages[model.onboardingStepIndex]

        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Step \(model.onboardingStepIndex + 1) of \(pages.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onboarding-step-indicator")
                Spacer()
                Button("Skip") {
                    model.skipOnboarding()
                }
                .accessibilityIdentifier("onboarding-skip-button")
            }

            Text(page.title)
                .font(.title2.weight(.semibold))
                .accessibilityIdentifier("onboarding-step-title")

            Text(page.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(height: 140, alignment: .top)
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier("onboarding-step-message")

            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == model.onboardingStepIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: index == model.onboardingStepIndex ? 20 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: model.onboardingStepIndex)
                }
            }
            .accessibilityIdentifier("onboarding-page-dots")

            LocalDemoActivityMenu(label: "Try Demo Activity")

            Spacer()

            Button {
                model.nextStep()
            } label: {
                Text(model.onboardingStepIndex == pages.count - 1 ? "Get Started" : "Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("onboarding-next-button")
        }
    }
}

private struct AuthScreen: View {
    @EnvironmentObject private var model: ReportKitSimpleAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Account")
                    .font(.headline)
                Spacer()
                Button("View intro again") {
                    model.restartOnboarding()
                }
                .font(.subheadline)
                .accessibilityIdentifier("view-intro-again-button")
            }

            Picker("Auth Mode", selection: $model.authMode) {
                Text("Sign In").tag(AuthMode.signIn)
                Text("Sign Up").tag(AuthMode.signUp)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("auth-mode-toggle")

            Text(model.authMode == .signIn ? "Sign in with your ReportKit account to upload activity tokens." : "Create your ReportKit account with email and password.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Try a demo Live Activity before signing in.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LocalDemoActivityMenu(label: "Demo Live Activities")
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField("Email", text: $model.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .padding(14)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("auth-email-field")

                SecureField("Password", text: $model.password)
                    .textContentType(.password)
                    .padding(14)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("auth-password-field")
            }

            Button {
                Task {
                    if model.authMode == .signIn {
                        await model.signIn()
                    } else {
                        await model.signUp()
                    }
                }
            } label: {
                Text(model.isWorking ? (model.authMode == .signIn ? "Signing In…" : "Creating account…") : (model.authMode == .signIn ? "Sign In" : "Sign Up"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isWorking)
            .accessibilityIdentifier(model.authMode == .signIn ? "sign-in-button" : "sign-up-button")

            StatusMessageView()
            Spacer()
        }
    }
}

private struct SignedInScreen: View {
    @EnvironmentObject private var model: ReportKitSimpleAppModel
    let session: UserSessionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Signed in as \(session.email)")
                .font(.headline)

            statusCard(
                title: "Token Sync",
                rows: [
                    ("Push-to-start", model.tokenStatus.pushToStartToken.isEmpty ? "Waiting" : "Ready"),
                    ("Device token", model.tokenStatus.deviceToken.isEmpty ? "Waiting" : "Ready"),
                    ("Notifications", model.tokenStatus.notificationsAuthorized ? "Allowed" : "Not granted"),
                    ("Alarm scheduling", model.tokenStatus.alarmsEnabled ? "Enabled" : "Not enabled"),
                    ("Push upload", model.tokenStatus.lastPushUploadAt?.formatted(date: .omitted, time: .shortened) ?? "Pending"),
                    ("Device upload", model.tokenStatus.lastDeviceUploadAt?.formatted(date: .omitted, time: .shortened) ?? "Pending"),
                    ("Last alarm", model.tokenStatus.lastAlarmStatus.isEmpty ? "No push handled yet" : model.tokenStatus.lastAlarmStatus),
                    ("Alarm source", model.tokenStatus.lastAlarmSource.isEmpty ? "N/A" : model.tokenStatus.lastAlarmSource),
                    ("Alarm updated", model.tokenStatus.lastAlarmUpdatedAt?.formatted(date: .omitted, time: .shortened) ?? "Never")
                ]
            )

            HStack(spacing: 12) {
                LocalDemoActivityMenu(label: "Local Test Activity")

                Button("Enable Alarms") {
                    Task { await model.enableAlarmScheduling() }
                }
                .buttonStyle(.bordered)
                .disabled(model.isWorking)

                Button("Refresh Status") {
                    Task { await model.refresh() }
                }
                .buttonStyle(.borderedProminent)

                Button("Sign Out") {
                    Task { await model.signOut() }
                }
                .buttonStyle(.bordered)
            }

            StatusMessageView()
            Spacer()
        }
        .task {
            await model.refreshTokenStatus()
        }
    }

    private func statusCard(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(row.1)
                        .multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct LocalDemoActivityMenu: View {
    @EnvironmentObject private var model: ReportKitSimpleAppModel

    let label: String

    var body: some View {
        Menu(label) {
            ForEach(ReportKitSimpleVisualStyle.allCases, id: \.self) { style in
                Section(style.title) {
                    ForEach(ReportKitSimpleDemoScenario.scenarios(for: style)) { scenario in
                        Button(scenario.menuTitle) {
                            Task { await model.startLocalTestActivity(scenario: scenario) }
                        }
                    }
                }
            }
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("local-demo-activity-menu")
    }
}

private struct StatusMessageView: View {
    @EnvironmentObject private var model: ReportKitSimpleAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let infoMessage = model.infoMessage {
                Text(infoMessage)
                    .foregroundStyle(.secondary)
            }
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("error-message")
            }
        }
        .font(.footnote)
    }
}

private struct RootPreviewContainer: View {
    let model: ReportKitSimpleAppModel

    init(
        phase: ReportKitSimplePhase,
        tokenStatus: TokenStatusSnapshot,
        onboardingStepIndex: Int = 0,
        authMode: AuthMode = .signIn,
        hasSeenOnboarding: Bool = true
    ) {
        let model = ReportKitSimpleAppModel()
        model.phase = phase
        model.tokenStatus = tokenStatus
        model.configurePreviewSignedOutState(
            onboardingStepIndex: onboardingStepIndex,
            authMode: authMode,
            hasSeenOnboarding: hasSeenOnboarding
        )
        self.model = model
    }

    var body: some View {
        ReportKitSimpleRootView()
            .environmentObject(model)
    }
}

#Preview("Onboarding Step 1") {
    RootPreviewContainer(phase: .signedOut(.onboarding), tokenStatus: .empty, onboardingStepIndex: 0, hasSeenOnboarding: false)
}

#Preview("Onboarding Step 2") {
    RootPreviewContainer(phase: .signedOut(.onboarding), tokenStatus: .empty, onboardingStepIndex: 1, hasSeenOnboarding: false)
}

#Preview("Onboarding Step 3") {
    RootPreviewContainer(phase: .signedOut(.onboarding), tokenStatus: .empty, onboardingStepIndex: 2, hasSeenOnboarding: false)
}

#Preview("Signed Out Auth") {
    RootPreviewContainer(phase: .signedOut(.auth), tokenStatus: .empty, authMode: .signUp)
}

#Preview("Signed In") {
    RootPreviewContainer(
        phase: .signedIn(UserSessionSnapshot(userID: "user", email: "user@example.com")),
        tokenStatus: TokenStatusSnapshot(
            pushToStartToken: "abc",
            deviceToken: "def",
            lastPushUploadAt: .now,
            lastDeviceUploadAt: .now,
            notificationsAuthorized: true,
            alarmsEnabled: true,
            lastAlarmStatus: "Scheduled",
            lastAlarmSource: "background-fetch",
            lastAlarmUpdatedAt: .now
        )
    )
}
