import UIKit
import UserNotifications

final class ReportKitSimpleAppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            Task { @MainActor in
                _ = await self.handleAlarmIfPossible(userInfo: userInfo, source: "launch")
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        ReportKitSimplePushTokenRegistrar.shared.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            let scheduled = await handleAlarmIfPossible(userInfo: userInfo, source: "background-fetch")
            completionHandler(scheduled ? .newData : .noData)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("ReportKitSimpleAppDelegate: remote notification registration failed: \(error.localizedDescription)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            _ = await handleAlarmIfPossible(userInfo: notification.request.content.userInfo, source: "foreground")
            completionHandler([.banner, .list, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            _ = await handleAlarmIfPossible(
                userInfo: response.notification.request.content.userInfo,
                source: "notification-response"
            )
            completionHandler()
        }
    }

    @MainActor
    private func handleAlarmIfPossible(userInfo: [AnyHashable: Any], source: String) async -> Bool {
        guard #available(iOS 26.0, *) else {
            RemoteAlarmDiagnostics.shared.record(
                status: "Unsupported OS",
                source: source,
                alarmID: nil,
                detail: UIDevice.current.systemVersion
            )
            return false
        }

        return await RemoteAlarmHandler.handle(userInfo: userInfo, source: source)
    }
}
