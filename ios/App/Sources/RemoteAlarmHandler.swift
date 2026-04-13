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
    static func handle(userInfo: [AnyHashable: Any]) {
        guard let reportkit = userInfo["reportkit"] as? [String: Any],
              let alarmDict = reportkit["alarm"] as? [String: Any] else {
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: alarmDict)
            let command = try JSONDecoder().decode(RemoteAlarmCommand.self, from: data)
            schedule(command)
        } catch {
            print("RemoteAlarmHandler: failed to decode alarm payload: \(error)")
        }
    }

    private static func schedule(_ command: RemoteAlarmCommand) {
        let title = command.title.isEmpty ? "Alarm" : command.title

        if let seconds = command.fireInSeconds {
            Task { @MainActor in
                let when = Date().addingTimeInterval(max(1, seconds))
                await CalendarAlarmManager.shared.scheduleOneShot(time: when, title: title)
            }
            return
        }

        if let fireAt = command.fireAt {
            let formatter = ISO8601DateFormatter()
            if let when = formatter.date(from: fireAt) {
                Task { @MainActor in
                    await CalendarAlarmManager.shared.scheduleOneShot(time: when, title: title)
                }
            }
        }
    }
}
