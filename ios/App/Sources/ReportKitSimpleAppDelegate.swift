import UIKit

final class ReportKitSimpleAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
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
            if #available(iOS 26.0, *) {
                let scheduled = await RemoteAlarmHandler.handle(userInfo: userInfo)
                completionHandler(scheduled ? .newData : .noData)
            } else {
                completionHandler(.noData)
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("ReportKitSimpleAppDelegate: remote notification registration failed: \(error.localizedDescription)")
    }
}
