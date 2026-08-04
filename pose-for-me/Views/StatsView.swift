import Combine
import SwiftUI
import Charts

/// Progress dashboard: 14-day activity chart, streak and lifetime totals.
struct StatsView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Progress")
                    .font(.appLargeTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 8)

                statRow

                WeeklyRecapSection()

                shieldRow

                chartCard

                categoryCard

                personalBestsCard

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

    private var shieldRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.fill")
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(sessionStore.streakShields) streak shield\(sessionStore.streakShields == 1 ? "" : "s")")
                    .font(.body(14, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Earn one every \(SessionStore.sessionsPerShield) stretches — a shield auto-covers a missed day.")
                    .font(.appCaption2)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
        }
        .card(padding: 14)
    }

    private var categoryCard: some View {
        let totals = sessionStore.categoryTotals()
        let maxCount = totals.first?.count ?? 1
        return Group {
            if !totals.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Overline("By focus area")
                    ForEach(totals, id: \.category) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Image(systemName: item.category.symbol)
                                    .font(.appCaption)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 22)
                                Text(item.category.rawValue)
                                    .font(.body(14, .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(item.count) · \(Int(item.minutes.rounded())) min")
                                    .font(.appCaption.monospacedDigit())
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.track)
                                    Capsule().fill(Theme.accent)
                                        .frame(width: geo.size.width
                                               * CGFloat(item.count) / CGFloat(max(1, maxCount)))
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                }
                .card()
            }
        }
    }

    private var personalBestsCard: some View {
        let top = Array(sessionStore.exerciseTotals().prefix(3))
        return Group {
            if !top.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Overline("Personal bests")
                    ForEach(top, id: \.exercise.id) { item in
                        HStack {
                            Image(systemName: item.exercise.category.symbol)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.exercise.name)
                                    .font(.body(15, .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(item.count) session\(item.count == 1 ? "" : "s")")
                                    .font(.appCaption2)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            Spacer()
                            if let best = item.bestForm {
                                Text("Best form \(Int(best * 100))%")
                                    .font(.body(12, .bold).monospacedDigit())
                                    .foregroundStyle(best > 0.6 ? Theme.success : Theme.warning)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .card()
            }
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Overline("Last 14 days")

            let data = sessionStore.dailyCounts(days: 14)
            Chart(data, id: \.day) { item in
                BarMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("Stretches", item.count)
                )
                .foregroundStyle(Theme.accent)
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

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Overline("Recent sessions")

            let visible = Array(sessionStore.records.suffix(30).reversed())

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
