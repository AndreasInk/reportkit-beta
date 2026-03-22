import Foundation
import ActivityKit
import SwiftUI

protocol ReportKitSimpleAuthenticating: Sendable {
    func currentSession() async -> UserSessionSnapshot?
    func signIn(email: String, password: String) async throws -> UserSessionSnapshot
    func signUp(email: String, password: String) async throws -> UserSessionSnapshot?
    func signOut() async
}

private enum ReportKitSimpleDefaults {
    static let seenOnboardingKey = "ReportKitSimpleHasSeenOnboarding"
}

private enum ReportKitSimpleLaunchFlags {
    static let resetOnboarding = "-ReportKitSimpleResetOnboarding"
}

@MainActor
final class ReportKitSimpleAppModel: ObservableObject {
    @Published var phase: ReportKitSimplePhase = .launching
    @Published var email = ""
    @Published var password = ""
    @Published var authMode: AuthMode = .signIn
    @Published var tokenStatus: TokenStatusSnapshot = .empty
    @Published var isWorking = false
    @Published var infoMessage: String?
    @Published var errorMessage: String?
    @Published private(set) var isPreviewMode = false
    @Published var hasSeenOnboarding: Bool

    private let userDefaults: UserDefaults
    private let authProvider: any ReportKitSimpleAuthenticating

    init(authProvider: any ReportKitSimpleAuthenticating = ReportKitSimpleSupabaseAuth.shared,
         userDefaults: UserDefaults = .standard
    ) {
        self.authProvider = authProvider
        self.userDefaults = userDefaults
        let shouldReset = ProcessInfo.processInfo.arguments.contains(ReportKitSimpleLaunchFlags.resetOnboarding)
        if shouldReset {
            userDefaults.removeObject(forKey: ReportKitSimpleDefaults.seenOnboardingKey)
        }
        self.hasSeenOnboarding = userDefaults.bool(forKey: ReportKitSimpleDefaults.seenOnboardingKey)
    }

    func markOnboardingSeen() {
        guard !hasSeenOnboarding else { return }
        hasSeenOnboarding = true
        userDefaults.setValue(true, forKey: ReportKitSimpleDefaults.seenOnboardingKey)
    }

    func refresh() async {
        if let previewPhase = previewPhaseOverride() {
            isPreviewMode = true
            phase = previewPhase
            tokenStatus = previewTokenStatus()
            hasSeenOnboarding = true
            return
        }

        isPreviewMode = false

        defer {
            Task { @MainActor in
                self.tokenStatus = await ReportKitSimplePushTokenRegistrar.shared.currentStatus()
            }
        }

        if let session = await authProvider.currentSession() {
            phase = .signedIn(session)
            await ReportKitSimplePushTokenRegistrar.shared.prepareForAuthenticatedUse()
        } else {
            phase = .signedOut
        }
    }

    func signIn() async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Email is required."
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Password is required."
            return
        }

        isWorking = true
        infoMessage = nil
        errorMessage = nil
        defer { isWorking = false }

        do {
            markOnboardingSeen()
            _ = try await authProvider.signIn(email: email, password: password)
            infoMessage = "Signed in."
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp() async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Email is required."
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Password is required."
            return
        }

        isWorking = true
        infoMessage = nil
        errorMessage = nil
        defer { isWorking = false }

        do {
            markOnboardingSeen()
            let session = try await authProvider.signUp(email: email, password: password)
            if let session {
                infoMessage = "Account created and signed in as \(session.email)."
                phase = .signedIn(session)
                await ReportKitSimplePushTokenRegistrar.shared.prepareForAuthenticatedUse()
            } else {
                infoMessage = "Account created. Please check your email to confirm before signing in."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        isWorking = true
        defer { isWorking = false }

        await authProvider.signOut()
        infoMessage = "Signed out."
        await refresh()
    }

    func refreshTokenStatus() async {
        if isPreviewMode {
            tokenStatus = previewTokenStatus()
            return
        }
        tokenStatus = await ReportKitSimplePushTokenRegistrar.shared.currentStatus()
    }

    func startLocalTestActivity() async {
        await startLocalTestActivity(style: .minimal)
    }

    func startLocalTestActivity(style: ReportKitSimpleVisualStyle = .minimal) async {
        isWorking = true
        errorMessage = nil
        infoMessage = nil
        defer { isWorking = false }

        do {
            let activity = try Activity.request(
                attributes: ReportKitSimpleAttributes(reportID: "local-test-\(UUID().uuidString)"),
                content: ActivityContent(
                    state: ReportKitSimpleAttributes.ContentState(
                        generatedAt: Int64(Date().timeIntervalSince1970),
                        title: "ReportKitSimple Local Test",
                        summary: "This live activity was started directly from the app.",
                        status: .good,
                        action: "Tap and inspect rendering.",
                        deepLink: nil,
                        visualStyle: style,
                        chartValues: style == .chart
                        ? [18, 24, 21, 35, 44, 55, 62]
                        : nil,
                        chartTitle: style == .chart
                        ? "Demo Trend"
                        : nil
                    ),
                    staleDate: Date().addingTimeInterval(20 * 60)
                )
            )

            infoMessage = "Local activity started: \(activity.id)"
        } catch {
            errorMessage = "Unable to start local activity: \(error.localizedDescription)"
        }
    }

    private func previewPhaseOverride() -> ReportKitSimplePhase? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-ReportKitSimplePreviewState"), arguments.indices.contains(index + 1) else {
            return nil
        }

        switch arguments[index + 1] {
        case "signedOut":
            return .signedOut
        case "signedIn":
            return .signedIn(UserSessionSnapshot(userID: "preview-user", email: "preview@example.com"))
        default:
            return nil
        }
    }

    private func previewTokenStatus() -> TokenStatusSnapshot {
        TokenStatusSnapshot(
            pushToStartToken: "preview-push-token",
            deviceToken: "preview-device-token",
            lastPushUploadAt: .now,
            lastDeviceUploadAt: .now,
            notificationsAuthorized: true
        )
    }
}
