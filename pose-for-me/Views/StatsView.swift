import Combine
import SwiftUI
import Charts

/// Progress dashboard: 14-day activity chart, streak and lifetime totals.
struct StatsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var entitlements: Entitlements
    @Binding var showPaywall: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Progress")
                    .font(.appLargeTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 8)

                statRow

                chartCard

                if !entitlements.isPro {
                    proUpsell
                }

                recentList
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }

    private var statRow: some View {
        HStack(spacing: 12) {
            bigStat(value: "\(sessionStore.streakDays)", label: "day streak",
                    symbol: "flame.fill", color: Theme.ember)
            bigStat(value: "\(sessionStore.records.count)", label: "total stretches",
                    symbol: "figure.flexibility", color: Theme.accent)
            bigStat(value: String(format: "%.0f", sessionStore.records.reduce(0) { $0 + $1.durationSeconds } / 60),
                    label: "total minutes", symbol: "clock.fill", color: Theme.mintSoft)
        }
    }

    private func bigStat(value: String, label: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(value)
                .font(.appTitle2)
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.appCaption2)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 14)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 14 days")
                .font(.appHeadline)
                .foregroundStyle(Theme.textPrimary)

            let data = sessionStore.dailyCounts(days: 14)
            Chart(data, id: \.day) { item in
                BarMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("Stretches", item.count)
                )
                .foregroundStyle(Theme.brandGradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Theme.tintFill)
                    AxisValueLabel().foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: 180)
        }
        .card()
    }

    private var proUpsell: some View {
        Button { showPaywall = true } label: {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock full history & form scores")
                        .font(.body(15, .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Pro keeps every session and tracks your form over time.")
                        .font(.appCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .card()
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent sessions")
                .font(.appHeadline)
                .foregroundStyle(Theme.textPrimary)

            let visible = entitlements.isPro
                ? Array(sessionStore.records.suffix(30).reversed())
                : Array(sessionStore.records.suffix(7).reversed())

            if visible.isEmpty {
                Text("No sessions yet — your first stretch is one tap away.")
                    .font(.appSubheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }

            ForEach(visible) { record in
                HStack {
                    Image(systemName: record.exercise?.category.symbol ?? "figure.stand")
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.exercise?.name ?? record.exerciseID)
                            .font(.body(15, .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(record.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.appCaption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    if let score = record.averageMatchScore {
                        Text("\(Int(score * 100))%")
                            .font(.body(12, .bold).monospacedDigit())
                            .foregroundStyle(score > 0.6 ? Theme.success : Theme.warning)
                    }
                    Text("\(Int(record.durationSeconds))s")
                        .font(.appCaption.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, 6)
            }
        }
        .card()
    }
}
