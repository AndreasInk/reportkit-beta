import Foundation

struct RemoteAlarmCommand: Codable {
    /// Display title for the alarm.
    var title: String

    /// Fire time in ISO8601, local or UTC.
    var fireAt: String?

    /// If provided, schedule `now + fireInSeconds`.
    var fireInSeconds: Double?

    /// Optional id for debugging or deduping.
    var id: String?
}
