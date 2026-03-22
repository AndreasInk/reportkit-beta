#if os(iOS)
import ActivityKit
import Foundation
import SwiftUI

struct ReportKitSimpleAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var generatedAt: Int64
        var title: String
        var summary: String
        var status: Status
        var action: String?
        var deepLink: String?
        var visualStyle: ReportKitSimpleVisualStyle?
        var chartValues: [Double]?
        var chartTitle: String?
    }

    var reportID: String
}

enum Status: String, Codable, Hashable, CaseIterable {
    case good
    case warning
    case critical

    var label: String {
        switch self {
        case .good:
            return "Good"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        }
    }

    var color: Color {
        switch self {
        case .good:
            return Color(red: 0.17, green: 0.58, blue: 0.31)
        case .warning:
            return Color(red: 0.83, green: 0.54, blue: 0.13)
        case .critical:
            return Color(red: 0.76, green: 0.22, blue: 0.18)
        }
    }
}

enum ReportKitSimpleVisualStyle: String, Codable, Hashable, CaseIterable {
    case minimal
    case banner
    case chart

    var title: String {
        switch self {
        case .minimal:
            return "Minimal"
        case .banner:
            return "Banner"
        case .chart:
            return "Chart"
        }
    }
}

extension ReportKitSimpleAttributes.ContentState {
    var resolvedVisualStyle: ReportKitSimpleVisualStyle {
        visualStyle ?? .minimal
    }

    var hasChartData: Bool {
        if let chartValues, !chartValues.isEmpty {
            return true
        }
        return false
    }
}

extension ReportKitSimpleAttributes.ContentState {
    static let preview = ReportKitSimpleAttributes.ContentState(
        generatedAt: 1_774_000_000,
        title: "Daily Pulse",
        summary: "Revenue is steady. Trial-to-paid dipped after yesterday's paywall experiment.",
        status: .warning,
        action: "Review the new paywall copy before noon.",
        deepLink: "https://mixpanel.com/project/demo",
        visualStyle: .chart,
        chartValues: [24, 31, 44, 58, 49, 67, 61],
        chartTitle: "Trial → Paid"
    )
}
#endif
