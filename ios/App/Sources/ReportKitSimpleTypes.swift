import Foundation

struct UserSessionSnapshot: Equatable {
    let userID: String
    let email: String
}

enum ReportKitSimplePhase: Equatable {
    case launching
    case signedOut
    case signedIn(UserSessionSnapshot)
}

struct TokenStatusSnapshot: Equatable {
    var pushToStartToken: String
    var deviceToken: String
    var lastPushUploadAt: Date?
    var lastDeviceUploadAt: Date?
    var notificationsAuthorized: Bool

    static let empty = TokenStatusSnapshot(
        pushToStartToken: "",
        deviceToken: "",
        lastPushUploadAt: nil,
        lastDeviceUploadAt: nil,
        notificationsAuthorized: false
    )
}
