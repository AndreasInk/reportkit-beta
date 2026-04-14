import Foundation

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
    static func handle(userInfo: [AnyHashable: Any]) async -> Bool {
        guard let reportkit = userInfo["reportkit"] as? [String: Any],
              let alarmDict = reportkit["alarm"] as? [String: Any] else {
            print("RemoteAlarmHandler: no reportkit.alarm payload present")
            return false
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: alarmDict)
            let command = try JSONDecoder().decode(RemoteAlarmCommand.self, from: data)
            return await schedule(command)
        } catch {
            print("RemoteAlarmHandler: failed to decode alarm payload: \(error)")
            return false
        }
    }

    @MainActor
    private static func schedule(_ command: RemoteAlarmCommand) async -> Bool {
        let title = command.title.isEmpty ? "Alarm" : command.title

        if let seconds = command.fireInSeconds {
            let when = Date().addingTimeInterval(max(1, seconds))
            return await CalendarAlarmManager.shared.scheduleOneShot(time: when, title: title)
        }

        if let fireAt = command.fireAt {
            let formatter = ISO8601DateFormatter()
            if let when = formatter.date(from: fireAt) {
                return await CalendarAlarmManager.shared.scheduleOneShot(time: when, title: title)
            }
            print("RemoteAlarmHandler: invalid fireAt timestamp: \(fireAt)")
        }

        print("RemoteAlarmHandler: no valid schedule fields in payload")
        return false
    }
}
