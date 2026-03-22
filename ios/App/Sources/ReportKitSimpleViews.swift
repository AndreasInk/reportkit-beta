import SwiftUI

struct ReportKitSimpleRootView: View {
    @EnvironmentObject private var model: ReportKitSimpleAppModel

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .launching:
                    ProgressView("Loading ReportKitSimple")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .signedOut:
                    AuthScreen()
                case .signedIn(let session):
                    SignedInScreen(session: session)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("ReportKitSimple")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await model.refresh()
        }
    }
}

private struct AuthScreen: View {
    @EnvironmentObject private var model: ReportKitSimpleAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !model.hasSeenOnboarding {
                Text("ReportKitSimple helps you sync ReportKit activity tokens from your phone so your Live Activity updates stay aligned with the latest report state.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onboarding-title")
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
                    ("Push upload", model.tokenStatus.lastPushUploadAt?.formatted(date: .omitted, time: .shortened) ?? "Pending"),
                    ("Device upload", model.tokenStatus.lastDeviceUploadAt?.formatted(date: .omitted, time: .shortened) ?? "Pending")
                ]
            )

            HStack(spacing: 12) {
                Menu("Local Test Activity") {
                    Button("Minimal") {
                        Task { await model.startLocalTestActivity(style: .minimal) }
                    }
                    Button("Banner") {
                        Task { await model.startLocalTestActivity(style: .banner) }
                    }
                    Button("Chart") {
                        Task { await model.startLocalTestActivity(style: .chart) }
                    }
                }
                .buttonStyle(.bordered)

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

    init(phase: ReportKitSimplePhase, tokenStatus: TokenStatusSnapshot) {
        let model = ReportKitSimpleAppModel()
        model.phase = phase
        model.tokenStatus = tokenStatus
        self.model = model
    }

    var body: some View {
        ReportKitSimpleRootView()
            .environmentObject(model)
    }
}

#Preview("Signed Out") {
    RootPreviewContainer(phase: .signedOut, tokenStatus: .empty)
}

#Preview("Signed In") {
    RootPreviewContainer(
        phase: .signedIn(UserSessionSnapshot(userID: "user", email: "user@example.com")),
        tokenStatus: TokenStatusSnapshot(
            pushToStartToken: "abc",
            deviceToken: "def",
            lastPushUploadAt: .now,
            lastDeviceUploadAt: .now,
            notificationsAuthorized: true
        )
    )
}
