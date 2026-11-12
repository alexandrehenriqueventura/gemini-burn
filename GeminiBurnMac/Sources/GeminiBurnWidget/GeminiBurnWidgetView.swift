import SwiftUI
import WidgetKit

struct GeminiBurnWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BurnEntry

    private var statusColor: Color {
        guard entry.isConnected else { return .secondary }
        let pct = entry.stats.today.pct
        if pct >= 70 { return .red }
        if pct >= 50 { return .orange }
        return .green
    }

    private var cleanPaceText: String {
        let raw = entry.stats.pace.label
        return raw
            .replacingOccurrences(of: "🔥", with: "")
            .replacingOccurrences(of: "⚡", with: "")
            .replacingOccurrences(of: "💤", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            default:
                largeView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Small Widget

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .widgetAccentable()
                Text("Gemini Burn")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(entry.stats.today.reqs)")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text("reqs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(entry.stats.today.totalTokensFmt) tokens")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: min(max(entry.stats.today.pct, 0), 100), total: 100)
                    .tint(statusColor)
                    .widgetAccentable()

                HStack {
                    Text("\(entry.stats.pace.reqsHour)/h")
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(entry.stats.today.pct.rounded()))%")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(statusColor)
                }
            }
        }
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        HStack(spacing: 14) {
            // Left: Today summary
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .widgetAccentable()
                    Text("Gemini Burn")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(cleanPaceText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(statusColor)
                }

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(entry.stats.today.reqs)")
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Text("reqs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(entry.stats.today.totalTokensFmt) tokens")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(entry.stats.pace.reqsHour) req/h")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text("\(entry.stats.today.tokensInFmt) in • \(entry.stats.today.tokensOutFmt) out")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                VStack(spacing: 3) {
                    ProgressView(value: min(max(entry.stats.today.pct, 0), 100), total: 100)
                        .tint(statusColor)
                        .widgetAccentable()
                    HStack {
                        Text("\(entry.stats.today.reqs) de \(entry.stats.today.limit) diárias")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f", entry.stats.today.pct))%")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(statusColor)
                    }
                }
            }

            Divider()

            // Right: Week & 7-Day Chart
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Semana")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("\(entry.stats.week.reqs) reqs")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text("\(entry.stats.week.totalTokensFmt) tokens")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                nativeChartBars(height: 36)
            }
            .frame(width: 112)
        }
    }

    // MARK: - Large Widget

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .widgetAccentable()
                    Text("Gemini Burn")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text(entry.isConnected ? cleanPaceText : "Offline")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
            }

            // Today Hero Section
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(entry.stats.today.reqs)")
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Text("reqs hoje")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(entry.stats.today.totalTokensFmt) tokens (\(entry.stats.today.tokensInFmt) in • \(entry.stats.today.tokensOutFmt) out)")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(entry.stats.pace.reqsHour)/h")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text("\(String(format: "%.1f", entry.stats.today.pct))%")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(statusColor)
                    }
                }

                ProgressView(value: min(max(entry.stats.today.pct, 0), 100), total: 100)
                    .tint(statusColor)
                    .widgetAccentable()
            }

            Divider()

            // Secondary Metrics Row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Semana", systemImage: "calendar")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("\(entry.stats.week.reqs) reqs")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text("\(entry.stats.week.totalTokensFmt) tokens")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Label("Ferramentas", systemImage: "wrench.and.screwdriver")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("\(entry.stats.session.toolsCount)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text("última: \(entry.stats.session.lastActive)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // 7-Day Chart
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Últimos 7 dias")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    let maxReqs = max(entry.stats.sparkline.map(\.reqs).max() ?? 0, 10)
                    Text("pico: \(maxReqs)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
                nativeChartBars(height: 52)
            }

            Spacer(minLength: 0)

            // Footer
            HStack {
                Label(entry.stats.session.model, systemImage: "cpu")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(entry.stats.updatedAt)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Native Bar Chart

    private func nativeChartBars(height: CGFloat) -> some View {
        let days = entry.stats.sparkline
        let maxReqs = max(days.map(\.reqs).max() ?? 0, 10)

        return HStack(alignment: .bottom, spacing: 6) {
            if days.isEmpty {
                Text("Sem histórico")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: height)
            } else {
                ForEach(days) { day in
                    let ratio = CGFloat(day.reqs) / CGFloat(maxReqs)
                    let barH = max(3, ratio * height)
                    VStack(spacing: 3) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(day.isToday ? AnyShapeStyle(statusColor) : AnyShapeStyle(.quaternary))
                            .frame(height: barH)
                            .widgetAccentable(day.isToday)
                        Text(day.label)
                            .font(.system(size: 9, weight: day.isToday ? .semibold : .regular))
                            .foregroundStyle(day.isToday ? .primary : .secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: height + 14)
    }
}
