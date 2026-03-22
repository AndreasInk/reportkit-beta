import Foundation

/// Stores and restores the per-device install identifier used by token upload rows.
///
/// Keeping this in UserDefaults is enough for v2.
enum DeviceInstallStore {
    private static let key = "reportkit.simple.deviceInstallID"

    static func installID() -> String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}
