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

    func scheduleOneShot(time: Date, title: String) async {
        guard #available(iOS 26.0, *) else { return }
        let now = Date()
        let targetTime = time > now ? time : now.addingTimeInterval(1)
        await applySchedule(.fixed(targetTime), title: title)
    }

    @available(iOS 26.0, *)
    private func applySchedule(_ schedule: Alarm.Schedule, title: String) async {
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
        } catch {
            print("CalendarAlarmManager: failed to schedule alarm: \(error)")
        }
    }
}

#else
@MainActor
final class CalendarAlarmManager {
    static let shared = CalendarAlarmManager()
    private init() {}
    func requestPermissions() async throws {}
    func scheduleOneShot(time: Date, title: String) async {}
}
#endif
#else
@MainActor
final class CalendarAlarmManager {
    static let shared = CalendarAlarmManager()
    private init() {}
    func requestPermissions() async throws {}
    func scheduleOneShot(time: Date, title: String) async {}
}
#endif
