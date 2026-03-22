import Foundation
import ActivityKit
import SwiftUI

@MainActor
final class ReportKitSimpleAppModel: ObservableObject {
    @Published var phase: ReportKitSimplePhase = .launching
    @Published var email = ""
    @Published var password = ""
    @Published var tokenStatus: TokenStatusSnapshot = .empty
    @Published var isWorking = false
    @Published var infoMessage: String?
    @Published var errorMessage: String?
    @Published private(set) var isPreviewMode = false

    func refresh() async {
        if let previewPhase = previewPhaseOverride() {
            isPreviewMode = true
            phase = previewPhase
            tokenStatus = previewTokenStatus()
            return
        }

        isPreviewMode = false

        defer {
            Task { @MainActor in
                self.tokenStatus = await ReportKitSimplePushTokenRegistrar.shared.currentStatus()
            }
        }

        if let session = await ReportKitSimpleSupabaseAuth.shared.currentSession() {
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
            _ = try await ReportKitSimpleSupabaseAuth.shared.signIn(email: email, password: password)
            infoMessage = "Signed in."
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        isWorking = true
        defer { isWorking = false }

        await ReportKitSimpleSupabaseAuth.shared.signOut()
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
