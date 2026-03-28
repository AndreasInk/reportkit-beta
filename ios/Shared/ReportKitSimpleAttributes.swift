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

enum ReportKitSimpleDemoScenario: String, CaseIterable, Hashable, Identifiable {
    case opsCalm
    case releaseReadiness
    case mixpanelFunnel
    case appStoreAnalytics
    case supabaseErrors
    case gcloudIncident

    var id: String { rawValue }

    var reportID: String {
        "demo-\(rawValue)"
    }

    var title: String {
        switch self {
        case .opsCalm:
            return "Ops Calm"
        case .releaseReadiness:
            return "Release Readiness"
        case .mixpanelFunnel:
            return "Mixpanel Funnel"
        case .appStoreAnalytics:
            return "App Store Analytics"
        case .supabaseErrors:
            return "Supabase Errors"
        case .gcloudIncident:
            return "GCloud Incident"
        }
    }

    var context: String {
        switch self {
        case .opsCalm:
            return "passive executive glance"
        case .releaseReadiness:
            return "ship room"
        case .mixpanelFunnel:
            return "Mixpanel insight"
        case .appStoreAnalytics:
            return "App Store Connect"
        case .supabaseErrors:
            return "Supabase logs"
        case .gcloudIncident:
            return "GCloud logs"
        }
    }

    var menuTitle: String {
        "\(title) (\(context))"
    }

    var visualStyle: ReportKitSimpleVisualStyle {
        switch self {
        case .opsCalm, .releaseReadiness:
            return .minimal
        case .supabaseErrors, .gcloudIncident:
            return .banner
        case .mixpanelFunnel, .appStoreAnalytics:
            return .chart
        }
    }

    static func scenarios(for style: ReportKitSimpleVisualStyle) -> [ReportKitSimpleDemoScenario] {
        allCases.filter { $0.visualStyle == style }
    }

    static func defaultScenario(for style: ReportKitSimpleVisualStyle) -> ReportKitSimpleDemoScenario {
        scenarios(for: style).first ?? .opsCalm
    }

    func contentState(now: Date = .now) -> ReportKitSimpleAttributes.ContentState {
        let generatedAt = Int64(now.timeIntervalSince1970)

        switch self {
        case .opsCalm:
            return ReportKitSimpleAttributes.ContentState(
                generatedAt: generatedAt,
                title: title,
                summary: "No incidents are active. Revenue, payments, and API checks are all within normal range.",
                status: .good,
                action: "Keep the surface pinned for passive monitoring.",
                deepLink: "reportkitsimple://demo/ops-calm",
                visualStyle: visualStyle,
                chartValues: nil,
                chartTitle: nil
            )
        case .releaseReadiness:
            return ReportKitSimpleAttributes.ContentState(
                generatedAt: generatedAt,
                title: title,
                summary: "The release candidate is green, but one blocking item remains: verify the latest App Store metadata before shipping.",
                status: .warning,
                action: "Check the submission checklist and metadata diff.",
                deepLink: "reportkitsimple://demo/release-readiness",
                visualStyle: visualStyle,
                chartValues: nil,
                chartTitle: nil
            )
        case .mixpanelFunnel:
            return ReportKitSimpleAttributes.ContentState(
                generatedAt: generatedAt,
                title: title,
                summary: "Revenue is steady. Trial-to-paid dipped after yesterday's paywall experiment.",
                status: .warning,
                action: "Open the experiment and inspect the conversion cohort.",
                deepLink: "reportkitsimple://demo/mixpanel-funnel",
                visualStyle: visualStyle,
                chartValues: [24, 31, 44, 58, 49, 67, 61],
                chartTitle: "Trial -> Paid"
            )
        case .appStoreAnalytics:
            return ReportKitSimpleAttributes.ContentState(
                generatedAt: generatedAt,
                title: title,
                summary: "Product page conversion fell 18% after the new screenshots went live in the U.S. storefront.",
                status: .warning,
                action: "Compare screenshot sets and restore the better-performing variant.",
                deepLink: "reportkitsimple://demo/app-store-analytics",
                visualStyle: visualStyle,
                chartValues: [5.4, 5.3, 5.2, 4.9, 4.6, 4.5, 4.4],
                chartTitle: "Page Conversion (%)"
            )
        case .supabaseErrors:
            return ReportKitSimpleAttributes.ContentState(
                generatedAt: generatedAt,
                title: title,
                summary: "Edge function failures spiked to 127 in the last 10 minutes, mostly auth refresh and write timeouts.",
                status: .critical,
                action: "Open Supabase logs and roll back the latest function deploy.",
                deepLink: "reportkitsimple://demo/supabase-errors",
                visualStyle: visualStyle,
                chartValues: nil,
                chartTitle: nil
            )
        case .gcloudIncident:
            return ReportKitSimpleAttributes.ContentState(
                generatedAt: generatedAt,
                title: title,
                summary: "Cloud Run error rate crossed 4.2% and the newest deploy is returning upstream timeout bursts.",
                status: .critical,
                action: "Inspect GCloud logs and divert traffic from the failing revision.",
                deepLink: "reportkitsimple://demo/gcloud-incident",
                visualStyle: visualStyle,
                chartValues: nil,
                chartTitle: nil
            )
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

    var actionButtonText: String? {
        guard let action else { return nil }

        let trimmed = action
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count > 34 else { return trimmed }

        for separator in [" and ", " before ", " after ", ", "] {
            guard let range = trimmed.range(of: separator) else { continue }
            let candidate = String(trimmed[..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.count >= 12 {
                return candidate
            }
        }

        return String(trimmed.prefix(34))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension ReportKitSimpleAttributes.ContentState {
    static let preview = ReportKitSimpleDemoScenario.mixpanelFunnel.contentState(
        now: Date(timeIntervalSince1970: 1_774_000_000)
    )
}
#endif
