import Foundation
import SwiftUI

#if os(iOS)
#if canImport(AlarmKit)
import AlarmKit

private struct NoMetadata: AlarmMetadata {}

/// Minimal AlarmKit bridge for push-triggered alarms.
@MainActor
final class CalendarAlarmManager {
    static let shared = CalendarAlarmManager()

    private init() {}

    func requestPermissions() async throws {
        guard #available(iOS 26.0, *) else { return }
        _ = try await AlarmManager.shared.requestAuthorization()
    }

    func scheduleOneShot(time: Date, title: String) async -> Bool {
        guard #available(iOS 26.0, *) else {
            print("CalendarAlarmManager: AlarmKit unavailable on this OS version")
            return false
        }
        let now = Date()
        let targetTime = time > now ? time : now.addingTimeInterval(1)
        return await applySchedule(.fixed(targetTime), title: title)
    }

    @available(iOS 26.0, *)
    private func applySchedule(_ schedule: Alarm.Schedule, title: String) async -> Bool {
        let stopButton = AlarmButton(
            text: LocalizedStringResource("Dismiss"),
            textColor: .white,
            systemImageName: "stop.circle"
        )
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: stopButton
        )
        let attributes = AlarmAttributes<NoMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .accentColor
        )
        let configuration = AlarmManager.AlarmConfiguration<NoMetadata>(
            schedule: schedule,
            attributes: attributes
        )

        do {
            _ = try await AlarmManager.shared.schedule(id: UUID(), configuration: configuration)
            print("CalendarAlarmManager: scheduled alarm titled '\(title)'")
            return true
        } catch {
            print("CalendarAlarmManager: failed to schedule alarm: \(error)")
            return false
        }
    }
}

#else
@MainActor
final class CalendarAlarmManager {
    static let shared = CalendarAlarmManager()
    private init() {}
    func requestPermissions() async throws {}
    func scheduleOneShot(time: Date, title: String) async -> Bool { false }
}
#endif
#else
@MainActor
final class CalendarAlarmManager {
    static let shared = CalendarAlarmManager()
    private init() {}
    func requestPermissions() async throws {}
    func scheduleOneShot(time: Date, title: String) async -> Bool { false }
}
#endif
