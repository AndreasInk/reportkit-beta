import Foundation

enum AuthMode {
    case signIn
    case signUp
}

enum OnboardingEntryMode {
    case firstRun
    case revisit
}

enum SignedOutScreen: Equatable {
    case onboarding
    case auth
}

struct UserSessionSnapshot: Equatable {
    let userID: String
    let email: String
}

enum ReportKitSimplePhase: Equatable {
    case launching
    case signedOut(SignedOutScreen)
    case signedIn(UserSessionSnapshot)
}

struct TokenStatusSnapshot: Equatable {
    var pushToStartToken: String
    var deviceToken: String
    var deviceInstallID: String
    var apnsEnv: String
    var lastPushUploadAt: Date?
    var lastDeviceUploadAt: Date?
    var notificationsAuthorized: Bool
    var alarmsEnabled: Bool
    var lastAlarmStatus: String
    var lastAlarmSource: String
    var lastAlarmUpdatedAt: Date?

    static let empty = TokenStatusSnapshot(
        pushToStartToken: "",
        deviceToken: "",
        deviceInstallID: "",
        apnsEnv: "",
        lastPushUploadAt: nil,
        lastDeviceUploadAt: nil,
        notificationsAuthorized: false,
        alarmsEnabled: false,
        lastAlarmStatus: "",
        lastAlarmSource: "",
        lastAlarmUpdatedAt: nil
    )
}
