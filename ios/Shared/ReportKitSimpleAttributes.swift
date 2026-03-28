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
        var progressPercent: Double? = nil
        var completedSteps: Int? = nil
        var totalSteps: Int? = nil
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
    case progress

    var title: String {
        switch self {
        case .minimal:
            return "Minimal"
        case .banner:
            return "Banner"
        case .chart:
            return "Chart"
        case .progress:
            return "Progress"
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
    case codexAgentProgress

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
        case .codexAgentProgress:
            return "Agent Progress"
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
        case .codexAgentProgress:
            return "Codex task run"
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
        case .codexAgentProgress:
            return .progress
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
        case .codexAgentProgress:
            return ReportKitSimpleAttributes.ContentState(
                generatedAt: generatedAt,
                title: "Ship Agent Progress Template",
                summary: "Updated the widget payload schema and now wiring the Dynamic Island progress bar.",
                status: .warning,
                action: "Open the latest implementation notes.",
                deepLink: "reportkitsimple://demo/codex-agent-progress",
                visualStyle: visualStyle,
                chartValues: nil,
                chartTitle: nil,
                progressPercent: 68,
                completedSteps: 17,
                totalSteps: 25
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

    var normalizedProgressPercent: Double? {
        guard let progressPercent else { return nil }
        return min(max(progressPercent, 0), 100)
    }

    var normalizedStepCounts: (completed: Int, total: Int)? {
        guard
            let completedSteps,
            let totalSteps,
            totalSteps > 0
        else {
            return nil
        }

        let safeCompleted = min(max(completedSteps, 0), totalSteps)
        return (safeCompleted, totalSteps)
    }

    var progressFraction: Double? {
        if let normalizedProgressPercent {
            return normalizedProgressPercent / 100
        }

        if let normalizedStepCounts {
            return Double(normalizedStepCounts.completed) / Double(normalizedStepCounts.total)
        }

        return nil
    }

    var progressSummaryText: String? {
        let percentText: String? = {
            guard let normalizedProgressPercent else { return nil }
            return "\(Int(normalizedProgressPercent.rounded()))% complete"
        }()

        let stepText: String? = {
            guard let normalizedStepCounts else { return nil }
            return "\(normalizedStepCounts.completed) of \(normalizedStepCounts.total) steps"
        }()

        switch (percentText, stepText) {
        case let (percentText?, stepText?):
            return "\(percentText) • \(stepText)"
        case let (percentText?, nil):
            return percentText
        case let (nil, stepText?):
            return stepText
        case (nil, nil):
            return nil
        }
    }

    var compactProgressLabel: String? {
        if let normalizedProgressPercent {
            return "\(Int(normalizedProgressPercent.rounded()))%"
        }

        if let normalizedStepCounts {
            return "\(normalizedStepCounts.completed)/\(normalizedStepCounts.total)"
        }

        return nil
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
