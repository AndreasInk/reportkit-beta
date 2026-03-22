import ActivityKit
import Foundation
import UIKit
import UserNotifications

@MainActor
final class ReportKitSimplePushTokenRegistrar {
    static let shared = ReportKitSimplePushTokenRegistrar()

    private enum Keys {
        static let pushToken = "reportkit.simple.pushToStartToken"
        static let deviceToken = "reportkit.simple.deviceToken"
        static let lastPushUpload = "reportkit.simple.lastPushUpload"
        static let lastDeviceUpload = "reportkit.simple.lastDeviceUpload"
    }

    private var monitoringTask: Task<Void, Never>?

    func prepareForAuthenticatedUse() async {
        await requestNotificationPermissionIfNeeded()
        startMonitoringPushToken()
        await provisionPushToStartTokenIfNeeded()
        await uploadStoredTokensIfPossible()
    }

    func currentStatus() async -> TokenStatusSnapshot {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return TokenStatusSnapshot(
            pushToStartToken: UserDefaults.standard.string(forKey: Keys.pushToken) ?? "",
            deviceToken: UserDefaults.standard.string(forKey: Keys.deviceToken) ?? "",
            lastPushUploadAt: UserDefaults.standard.object(forKey: Keys.lastPushUpload) as? Date,
            lastDeviceUploadAt: UserDefaults.standard.object(forKey: Keys.lastDeviceUpload) as? Date,
            notificationsAuthorized: settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        )
    }

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: Keys.deviceToken)
        Task {
            await uploadDeviceTokenIfPossible(token)
        }
    }

    private func requestNotificationPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return
        }

        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private func startMonitoringPushToken() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task {
            for await tokenData in Activity<ReportKitSimpleAttributes>.pushToStartTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                UserDefaults.standard.set(token, forKey: Keys.pushToken)
                await uploadPushTokenIfPossible(token)
            }
        }
    }

    private func provisionPushToStartTokenIfNeeded() async {
        guard UserDefaults.standard.string(forKey: Keys.pushToken)?.isEmpty != false else {
            return
        }

        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else {
            return
        }

        do {
            let state = ReportKitSimpleAttributes.ContentState(
                generatedAt: Int64(Date().timeIntervalSince1970),
                title: "ReportKitSimple",
                summary: "Push-to-start provisioning",
                status: .good,
                action: nil,
                deepLink: nil
            )

            let activity = try Activity.request(
                attributes: ReportKitSimpleAttributes(reportID: "reportkit-simple-bootstrap"),
                content: .init(state: state, staleDate: nil),
                pushType: .token
            )

            let tokenReceived = await waitForPushToStartToken(timeout: 2_500_000_000)
            if tokenReceived, let token = UserDefaults.standard.string(forKey: Keys.pushToken), !token.isEmpty {
                await uploadPushTokenIfPossible(token)
            }
            await activity.end(nil, dismissalPolicy: .immediate)
        } catch {
            // Keep the app simple: ignore provisioning failure and rely on next refresh.
        }
    }

    private func waitForPushToStartToken(timeout nanoseconds: UInt64) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await tokenData in Activity<ReportKitSimpleAttributes>.pushToStartTokenUpdates {
                    let token = tokenData.map { String(format: "%02x", $0) }.joined()
                    if !token.isEmpty {
                        UserDefaults.standard.set(token, forKey: Keys.pushToken)
                        return true
                    }
                }
                return false
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: nanoseconds)
                return false
            }

            for await result in group {
                return result
            }
            return false
        }
    }

    private func uploadStoredTokensIfPossible() async {
        if let pushToken = UserDefaults.standard.string(forKey: Keys.pushToken), !pushToken.isEmpty {
            await uploadPushTokenIfPossible(pushToken)
        }
        if let deviceToken = UserDefaults.standard.string(forKey: Keys.deviceToken), !deviceToken.isEmpty {
            await uploadDeviceTokenIfPossible(deviceToken)
        }
    }

    private func uploadPushTokenIfPossible(_ token: String) async {
        struct Body: Encodable {
            let deviceInstallID: String
            let apnsEnv: String
            let tokenHex: String

            enum CodingKeys: String, CodingKey {
                case deviceInstallID = "device_install_id"
                case apnsEnv = "apns_env"
                case tokenHex = "token_hex"
            }
        }

        do {
            try await ReportKitSimpleSupabaseAuth.shared.invokeAuthenticatedFunction(
                "reportkit-token",
                body: Body(
                    deviceInstallID: DeviceInstallStore.installID(),
                    apnsEnv: ReportKitSimpleConfig.apnsEnv,
                    tokenHex: token
                )
            )
            UserDefaults.standard.set(Date(), forKey: Keys.lastPushUpload)
        } catch {
            // Keep the app simple: persist the token and retry on next authenticated refresh.
        }
    }

    private func uploadDeviceTokenIfPossible(_ token: String) async {
        struct Body: Encodable {
            let deviceInstallID: String
            let apnsEnv: String
            let tokenHex: String

            enum CodingKeys: String, CodingKey {
                case deviceInstallID = "device_install_id"
                case apnsEnv = "apns_env"
                case tokenHex = "token_hex"
            }
        }

        do {
            try await ReportKitSimpleSupabaseAuth.shared.invokeAuthenticatedFunction(
                "reportkit-device-token",
                body: Body(
                    deviceInstallID: DeviceInstallStore.installID(),
                    apnsEnv: ReportKitSimpleConfig.apnsEnv,
                    tokenHex: token
                )
            )
            UserDefaults.standard.set(Date(), forKey: Keys.lastDeviceUpload)
        } catch {
            // Keep the app simple: persist the token and retry on next authenticated refresh.
        }
    }
}
