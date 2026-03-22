import SwiftUI

@main
struct ReportKitSimpleApp: App {
    @UIApplicationDelegateAdaptor(ReportKitSimpleAppDelegate.self) private var appDelegate
    @StateObject private var model = ReportKitSimpleAppModel()

    var body: some Scene {
        WindowGroup {
            ReportKitSimpleRootView()
                .environmentObject(model)
        }
    }
}
