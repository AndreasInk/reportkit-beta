import ActivityKit
import SwiftUI
import WidgetKit

struct ReportKitSimpleLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReportKitSimpleAttributes.self) { context in
            ReportKitSimpleLiveActivityContent(state: context.state)
                .padding(16)
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
                Text(context.state.status.label)
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
        }
    }
}

private struct MinimalLockScreenContent: View {
    let state: ReportKitSimpleAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StatusPill(status: state.status)
                Spacer()
                TimeBadge(timestamp: state.generatedAt)
            }

            Text(state.title)
                .font(.headline)
                .lineLimit(1)

            Text(state.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)

            if let action = state.action, !action.isEmpty {
                ActionPill(text: action)
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
        VStack(alignment: .leading, spacing: 12) {
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
                .lineLimit(2)
        }
    }
}

private struct ChartBars: View {
    let values: [Double]
    let style: Status

    private let maxHeight: CGFloat = 45

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(style.color.opacity(0.82))
                    .frame(width: 10, height: maxHeight * CGFloat(value))
            }
        }
        .frame(height: maxHeight)
    }
}

private struct DynamicIslandBottom: View {
    let state: ReportKitSimpleAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let action = state.action, !action.isEmpty {
                Text(action)
                    .font(.caption)
                    .lineLimit(2)
            }

            if state.resolvedVisualStyle == .chart {
                let fallbackBars = fallbackChartValues
                let bars = state.hasChartData ? normalizedChartValues : normalized(fallbackBars)
                if !bars.isEmpty {
                    ChartBars(values: bars, style: state.status)
                        .frame(height: 14)
                }
            }

            Text(state.status.label)
                .font(.caption)
        }
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
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.12))
            .foregroundStyle(.primary)
            .clipShape(Capsule())
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
    ReportKitSimpleAttributes.ContentState(
        generatedAt: 1_774_000_100,
        title: "Minimal Report",
        summary: "Minimal mode keeps the view concise with no chart decoration.",
        status: .warning,
        action: "Consider re-running checks before noon.",
        deepLink: nil,
        visualStyle: .minimal,
        chartValues: nil,
        chartTitle: nil
    )
}

#Preview("Banner", as: .content, using: ReportKitSimpleAttributes(reportID: "preview-banner")) {
    ReportKitSimpleLiveActivity()
} contentStates: {
    ReportKitSimpleAttributes.ContentState(
        generatedAt: 1_774_000_200,
        title: "Banner Report",
        summary: "Banner mode includes title and status at a glance.",
        status: .good,
        action: "All metrics look normal right now.",
        deepLink: nil,
        visualStyle: .banner,
        chartValues: nil,
        chartTitle: nil
    )
}

#Preview("Chart", as: .content, using: ReportKitSimpleAttributes(reportID: "preview-chart")) {
    ReportKitSimpleLiveActivity()
} contentStates: {
    ReportKitSimpleAttributes.ContentState(
        generatedAt: 1_774_000_300,
        title: "Trend Report",
        summary: "Last seven points show steady gain across the key funnel stage.",
        status: .good,
        action: "Open funnel trend to confirm next step.",
        deepLink: nil,
        visualStyle: .chart,
        chartValues: [18, 24, 21, 35, 44, 55, 62],
        chartTitle: "Conversion"
    )
}
