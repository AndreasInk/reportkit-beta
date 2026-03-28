import ActivityKit
import SwiftUI
import WidgetKit

private enum LiveActivityLayout {
    static let outerHorizontalPadding: CGFloat = 18
    static let outerVerticalPadding: CGFloat = 14
    static let sectionSpacing: CGFloat = 12
    static let compactSectionSpacing: CGFloat = 10
    static let progressSpacing: CGFloat = 8
    static let chartSpacing: CGFloat = 10
    static let chartHeight: CGFloat = 40
    static let chartBarWidth: CGFloat = 10
    static let chartBarSpacing: CGFloat = 8
    static let progressBarHeight: CGFloat = 8
    static let compactProgressBarHeight: CGFloat = 6
    static let actionHorizontalPadding: CGFloat = 14
    static let actionVerticalPadding: CGFloat = 10
    static let actionCornerRadius: CGFloat = 16
}

struct ReportKitSimpleLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReportKitSimpleAttributes.self) { context in
            ReportKitSimpleLiveActivityContent(state: context.state)
                .padding(.horizontal, LiveActivityLayout.outerHorizontalPadding)
                .padding(.vertical, LiveActivityLayout.outerVerticalPadding)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.primary)
                .widgetURL(URL(string: context.state.deepLink ?? "reportkitsimple://home"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StatusPill(status: context.state.status)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimeBadge(timestamp: context.state.generatedAt)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DynamicIslandBottom(state: context.state)
                }
            } compactLeading: {
                StatusDot(status: context.state.status)
            } compactTrailing: {
                Text(context.state.compactProgressLabel ?? context.state.status.label)
                    .font(.caption2)
            } minimal: {
                StatusDot(status: context.state.status)
            }
        }
    }
}

private struct ReportKitSimpleLiveActivityContent: View {
    let state: ReportKitSimpleAttributes.ContentState

    var body: some View {
        switch state.resolvedVisualStyle {
        case .minimal:
            MinimalLockScreenContent(state: state)
        case .banner:
            BannerLockScreenContent(state: state)
        case .chart:
            ChartLockScreenContent(state: state)
        case .progress:
            ProgressLockScreenContent(state: state)
        }
    }
}

private struct MinimalLockScreenContent: View {
    let state: ReportKitSimpleAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: LiveActivityLayout.sectionSpacing) {
            HStack {
                StatusPill(status: state.status)
                Spacer()
                TimeBadge(timestamp: state.generatedAt)
            }

            Text(state.title)
                .font(.headline)

            Text(state.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
        }
    }
}

private struct BannerLockScreenContent: View {
    let state: ReportKitSimpleAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: LiveActivityLayout.compactSectionSpacing) {
            HStack {
                StatusPill(status: state.status)
                Spacer()
                TimeBadge(timestamp: state.generatedAt)
            }

            Text(state.title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .allowsTightening(true)

            Text(state.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            if let action = state.actionButtonText {
                ActionPill(text: action)
            }
        }
    }
}

private struct ProgressLockScreenContent: View {
    let state: ReportKitSimpleAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: LiveActivityLayout.progressSpacing) {
            HStack {
                StatusPill(status: state.status)
                Spacer()
                TimeBadge(timestamp: state.generatedAt)
            }

            Text(state.title)
                .font(.headline)
                .lineLimit(2)

            Text(state.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)

            if let progressFraction = state.progressFraction {
                ProgressBar(progress: progressFraction, color: state.status.color)
            }

            if let progressSummaryText = state.progressSummaryText {
                Text(progressSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ChartLockScreenContent: View {
    let state: ReportKitSimpleAttributes.ContentState

    private var values: [Double] {
        if let chartValues = state.chartValues, !chartValues.isEmpty {
            return chartValues
        }

        let base: Double = {
            switch state.status {
            case .good:
                return 72
            case .warning:
                return 47
            case .critical:
                return 27
            }
        }()

        return [base - 10, base - 4, base + 8, base - 2, base + 12, base + 7, base - 3]
    }

    private var normalizedValues: [Double] {
        let maxValue = values.max() ?? 1
        let safeMax = max(maxValue, 1)
        return values.map { max(0, $0 / safeMax) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LiveActivityLayout.chartSpacing) {
            HStack {
                StatusPill(status: state.status)
                Spacer()
                TimeBadge(timestamp: state.generatedAt)
            }

            Text(state.chartTitle ?? "Trend")
                .font(.headline)
                .lineLimit(1)

            ChartBars(values: normalizedValues, style: state.status)

            Text(state.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
        }
    }
}

private struct ChartBars: View {
    let values: [Double]
    let style: Status

    var body: some View {
        HStack(alignment: .bottom, spacing: LiveActivityLayout.chartBarSpacing) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(style.color.opacity(0.82))
                    .frame(
                        width: LiveActivityLayout.chartBarWidth,
                        height: LiveActivityLayout.chartHeight * CGFloat(value)
                    )
            }
        }
        .frame(height: LiveActivityLayout.chartHeight)
    }
}

private struct DynamicIslandBottom: View {
    let state: ReportKitSimpleAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(bottomText)
                .font(.caption)
                .lineLimit(state.resolvedVisualStyle == .progress ? 3 : 2)

            if state.resolvedVisualStyle == .progress, let progressFraction = state.progressFraction {
                ProgressBar(
                    progress: progressFraction,
                    color: state.status.color,
                    height: LiveActivityLayout.compactProgressBarHeight
                )
                .frame(height: LiveActivityLayout.compactProgressBarHeight)
            }

            if state.resolvedVisualStyle == .chart {
                let fallbackBars = fallbackChartValues
                let bars = state.hasChartData ? normalizedChartValues : normalized(fallbackBars)
                if !bars.isEmpty {
                    ChartBars(values: bars, style: state.status)
                        .frame(height: 14)
                }
            }

            if let progressSummaryText = state.progressSummaryText, state.resolvedVisualStyle == .progress {
                Text(progressSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(state.status.label)
                    .font(.caption)
            }
        }
    }

    private var bottomText: String {
        if state.resolvedVisualStyle == .progress {
            return state.summary
        }

        if let action = state.action, !action.isEmpty {
            return action
        }

        return state.summary
    }

    private var fallbackChartValues: [Double] {
        switch state.status {
        case .good:
            return [62, 68, 72, 75, 80, 82]
        case .warning:
            return [44, 46, 48, 52, 50, 51]
        case .critical:
            return [28, 24, 23, 20, 18, 16]
        }
    }

    private var normalizedChartValues: [Double] {
        normalized(state.chartValues ?? [])
    }

    private func normalized(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else { return [] }
        let maxValue = values.max() ?? 1
        let safeMax = max(maxValue, 1)
        return values.map { max(0, $0 / safeMax) }
    }
}

private struct ProgressBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = LiveActivityLayout.progressBarHeight

    var body: some View {
        let clampedProgress = min(max(progress, 0), 1)

        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.16))

                Capsule()
                    .fill(color)
                    .frame(width: max(geometry.size.width * clampedProgress, clampedProgress > 0 ? height : 0))
            }
        }
        .frame(height: height)
    }
}

private struct TimeBadge: View {
    let timestamp: Int64

    var body: some View {
        Text(Date(timeIntervalSince1970: TimeInterval(timestamp)), style: .time)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}

private struct StatusDot: View {
    let status: Status

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 10, height: 10)
    }
}

private struct StatusPill: View {
    let status: Status

    var body: some View {
        Text(status.label.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.color.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct ActionPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, LiveActivityLayout.actionHorizontalPadding)
            .padding(.vertical, LiveActivityLayout.actionVerticalPadding)
            .background(Color.accentColor.opacity(0.12))
            .foregroundStyle(.primary)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: LiveActivityLayout.actionCornerRadius,
                    style: .continuous
                )
            )
    }
}

#Preview("Live Activity", as: .content, using: ReportKitSimpleAttributes(reportID: "preview")) {
    ReportKitSimpleLiveActivity()
} contentStates: {
    ReportKitSimpleAttributes.ContentState.preview
}

#Preview("Minimal", as: .content, using: ReportKitSimpleAttributes(reportID: "preview-minimal")) {
    ReportKitSimpleLiveActivity()
} contentStates: {
    ReportKitSimpleDemoScenario.releaseReadiness.contentState(
        now: Date(timeIntervalSince1970: 1_774_000_100)
    )
}

#Preview("Banner", as: .content, using: ReportKitSimpleAttributes(reportID: "preview-banner")) {
    ReportKitSimpleLiveActivity()
} contentStates: {
    ReportKitSimpleDemoScenario.supabaseErrors.contentState(
        now: Date(timeIntervalSince1970: 1_774_000_200)
    )
}

#Preview("Chart", as: .content, using: ReportKitSimpleAttributes(reportID: "preview-chart")) {
    ReportKitSimpleLiveActivity()
} contentStates: {
    ReportKitSimpleDemoScenario.appStoreAnalytics.contentState(
        now: Date(timeIntervalSince1970: 1_774_000_300)
    )
}

#Preview("Progress", as: .content, using: ReportKitSimpleAttributes(reportID: "preview-progress")) {
    ReportKitSimpleLiveActivity()
} contentStates: {
    ReportKitSimpleDemoScenario.codexAgentProgress.contentState(
        now: Date(timeIntervalSince1970: 1_774_000_400)
    )
}

#Preview("Progress Critical", as: .content, using: ReportKitSimpleAttributes(reportID: "preview-progress-critical")) {
    ReportKitSimpleLiveActivity()
} contentStates: {
    ReportKitSimpleAttributes.ContentState(
        generatedAt: 1_774_000_500,
        title: "Recover Failed Deploy",
        summary: "Rolled back the API worker and now verifying that background jobs are draining normally.",
        status: .critical,
        action: "Open deploy timeline",
        deepLink: "reportkitsimple://demo/progress-critical",
        visualStyle: .progress,
        chartValues: nil,
        chartTitle: nil,
        progressPercent: 34,
        completedSteps: 3,
        totalSteps: 9
    )
}
