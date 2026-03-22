import UIKit

final class ReportKitSimpleAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        ReportKitSimplePushTokenRegistrar.shared.handleDeviceToken(deviceToken)
    }
}
