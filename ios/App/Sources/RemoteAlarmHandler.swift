import Foundation

struct RemoteAlarmSnapshot: Equatable {
    var status: String
    var source: String
    var updatedAt: Date?
}

@MainActor
final class RemoteAlarmDiagnostics {
    static let shared = RemoteAlarmDiagnostics()

    private enum Keys {
        static let lastAlarmID = "reportkit.simple.remoteAlarm.lastID"
        static let lastAlarmStatus = "reportkit.simple.remoteAlarm.lastStatus"
        static let lastAlarmSource = "reportkit.simple.remoteAlarm.lastSource"
        static let lastAlarmUpdatedAt = "reportkit.simple.remoteAlarm.lastUpdatedAt"
        static let lastAlarmDetail = "reportkit.simple.remoteAlarm.lastDetail"
    }

    private let defaults: UserDefaults
    private let duplicateWindow: TimeInterval

    init(defaults: UserDefaults = .standard, duplicateWindow: TimeInterval = 300) {
        self.defaults = defaults
        self.duplicateWindow = duplicateWindow
    }

    var snapshot: RemoteAlarmSnapshot {
        RemoteAlarmSnapshot(
            status: detailAwareStatus(),
            source: defaults.string(forKey: Keys.lastAlarmSource) ?? "",
            updatedAt: defaults.object(forKey: Keys.lastAlarmUpdatedAt) as? Date
        )
    }

    func shouldIgnoreDuplicate(_ alarmID: String?) -> Bool {
        guard let alarmID, !alarmID.isEmpty else { return false }
        guard defaults.string(forKey: Keys.lastAlarmID) == alarmID else { return false }
        guard let updatedAt = defaults.object(forKey: Keys.lastAlarmUpdatedAt) as? Date else { return false }
        return Date().timeIntervalSince(updatedAt) < duplicateWindow
    }

    func record(status: String, source: String, alarmID: String?, detail: String?) {
        defaults.set(status, forKey: Keys.lastAlarmStatus)
        defaults.set(source, forKey: Keys.lastAlarmSource)
        defaults.set(Date(), forKey: Keys.lastAlarmUpdatedAt)
        if let alarmID, !alarmID.isEmpty {
            defaults.set(alarmID, forKey: Keys.lastAlarmID)
        }
        if let detail, !detail.isEmpty {
            defaults.set(detail, forKey: Keys.lastAlarmDetail)
        } else {
            defaults.removeObject(forKey: Keys.lastAlarmDetail)
        }
    }

    private func detailAwareStatus() -> String {
        let status = defaults.string(forKey: Keys.lastAlarmStatus) ?? ""
        guard !status.isEmpty else { return "" }
        let detail = defaults.string(forKey: Keys.lastAlarmDetail) ?? ""
        guard !detail.isEmpty else { return status }
        return "\(status): \(detail)"
    }
}

enum RemoteAlarmHandler {
    /// Parse the APNs payload and schedule an AlarmKit alarm if possible.
    /// Expected payload:
    /// {
    ///   "aps": { ... },
    ///   "reportkit": {
    ///     "alarm": { "title": "Work", "fireInSeconds": 60 }
    ///   }
    /// }
    @MainActor
    static func handle(userInfo: [AnyHashable: Any], source: String) async -> Bool {
        guard let reportkit = userInfo["reportkit"] as? [String: Any],
              let alarmDict = reportkit["alarm"] as? [String: Any] else {
            print("RemoteAlarmHandler: no reportkit.alarm payload present")
            return false
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: alarmDict)
            let command = try JSONDecoder().decode(RemoteAlarmCommand.self, from: data)
            if RemoteAlarmDiagnostics.shared.shouldIgnoreDuplicate(command.id) {
                let label = command.title.isEmpty ? "Alarm" : command.title
                RemoteAlarmDiagnostics.shared.record(
                    status: "Duplicate ignored",
                    source: source,
                    alarmID: command.id,
                    detail: label
                )
                print("RemoteAlarmHandler: ignoring duplicate alarm id \(command.id ?? "<none>")")
                return false
            }
            return await schedule(command)
        } catch {
            RemoteAlarmDiagnostics.shared.record(
                status: "Decode failed",
                source: source,
                alarmID: nil,
                detail: error.localizedDescription
            )
            print("RemoteAlarmHandler: failed to decode alarm payload: \(error)")
            return false
        }
    }

    @MainActor
    private static func schedule(_ command: RemoteAlarmCommand) async -> Bool {
        let title = command.title.isEmpty ? "Alarm" : command.title

        if let seconds = command.fireInSeconds {
            let when = Date().addingTimeInterval(max(1, seconds))
            let scheduled = await CalendarAlarmManager.shared.scheduleOneShot(time: when, title: title)
            recordResult(scheduled, command: command, detail: "fires in \(Int(max(1, seconds)))s")
            return scheduled
        }

        if let fireAt = command.fireAt {
            let formatter = ISO8601DateFormatter()
            if let when = formatter.date(from: fireAt) {
                let scheduled = await CalendarAlarmManager.shared.scheduleOneShot(time: when, title: title)
                recordResult(scheduled, command: command, detail: fireAt)
                return scheduled
            }
            RemoteAlarmDiagnostics.shared.record(
                status: "Invalid fireAt",
                source: "payload-parse",
                alarmID: command.id,
                detail: fireAt
            )
            print("RemoteAlarmHandler: invalid fireAt timestamp: \(fireAt)")
        }

        RemoteAlarmDiagnostics.shared.record(
            status: "Missing schedule",
            source: "payload-parse",
            alarmID: command.id,
            detail: title
        )
        print("RemoteAlarmHandler: no valid schedule fields in payload")
        return false
    }

    @MainActor
    private static func recordResult(_ scheduled: Bool, command: RemoteAlarmCommand, detail: String) {
        let title = command.title.isEmpty ? "Alarm" : command.title
        RemoteAlarmDiagnostics.shared.record(
            status: scheduled ? "Scheduled" : "Schedule failed",
            source: "alarmkit",
            alarmID: command.id,
            detail: "\(title) • \(detail)"
        )
    }
}
