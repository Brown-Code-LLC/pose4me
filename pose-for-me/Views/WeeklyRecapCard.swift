import Combine
import SwiftUI

/// The shareable "my week in stretches" image. Rendered offscreen with
/// ImageRenderer at 3x, so it uses fixed brand colors (matching the widget)
/// rather than adaptive theme tokens — the export looks the same everywhere.
struct RecapShareCard: View {
    let summary: WeeklySummary
    let streakDays: Int

    private let mint = Color(red: 0x4e / 255, green: 0xe6 / 255, blue: 0xc1 / 255)
    private let ember = Color(red: 0xf5 / 255, green: 0x9e / 255, blue: 0x0b / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Pose4Me", systemImage: "figure.flexibility")
                    .font(.body(14, .bold))
                    .foregroundStyle(mint)
                Spacer()
                if streakDays > 0 {
                    Label("\(streakDays) day streak", systemImage: "flame.fill")
                        .font(.body(13, .bold))
                        .foregroundStyle(ember)
                }
            }

            Text("My week in stretches")
                .font(.display(24, .bold))
                .foregroundStyle(.white)
                .padding(.top, 22)

            Text("\(Int(summary.minutes.rounded())) min")
                .font(.display(56, .heavy))
                .foregroundStyle(mint)
                .padding(.top, 14)

            Text("\(summary.sessions) stretch\(summary.sessions == 1 ? "" : "es") · \(summary.activeDays) active day\(summary.activeDays == 1 ? "" : "s")")
                .font(.body(15, .medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 4)

            dayBars
                .padding(.top, 24)

            HStack(spacing: 14) {
                if let top = summary.topCategory {
                    Label(top.rawValue, systemImage: top.symbol)
                }
                if let best = summary.bestForm {
                    Label("Best form \(Int(best * 100))%", systemImage: "checkmark.seal.fill")
                }
            }
            .font(.body(12, .semibold))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.top, 22)

            Spacer(minLength: 0)

            Text("Stretch reminders with a camera coach — free on the App Store")
                .font(.body(11, .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(26)
        .frame(width: 360, height: 430, alignment: .topLeading)
        .background(
            LinearGradient(colors: [Color(red: 0.055, green: 0.15, blue: 0.125),
                                    Color(red: 0.043, green: 0.082, blue: 0.071)],
                           startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var dayBars: some View {
        let maxCount = max(1, summary.dayCounts.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(summary.dayCounts.enumerated()), id: \.offset) { index, count in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(count > 0 ? mint : Color.white.opacity(0.12))
                        .frame(height: count > 0 ? max(12, 52 * CGFloat(count) / CGFloat(maxCount)) : 6)
                    Text(dayLetter(index))
                        .font(.body(10, .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 76, alignment: .bottom)
    }

    /// Weekday letter for bar `index` (0 = six days ago, 6 = today).
    private func dayLetter(_ index: Int) -> String {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: index - 6, to: Date()) else { return "" }
        return calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day) - 1]
    }
}

/// Progress-tab card: this week's numbers plus a ShareLink for the rendered image.
struct WeeklyRecapSection: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var shareImage: UIImage?

    var body: some View {
        let summary = sessionStore.weeklySummary()
        Group {
            if summary.sessions > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Overline("This week")
                    HStack(spacing: 0) {
                        recapStat(value: "\(Int(summary.minutes.rounded()))", label: "minutes")
                        hairline
                        recapStat(value: "\(summary.sessions)", label: "stretches")
                        hairline
                        recapStat(value: "\(summary.activeDays)/7", label: "active days")
                    }
                    if let image = shareImage {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview("My week in Pose4Me", image: Image(uiImage: image))
                        ) {
                            Label("Share my week", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .card()
                .onAppear { renderCard(summary) }
                .onChange(of: summary) { _, latest in renderCard(latest) }
            }
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Theme.cardStroke)
            .frame(width: 1, height: 30)
    }

    private func recapStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.display(20, .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.appCaption)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func renderCard(_ summary: WeeklySummary) {
        let renderer = ImageRenderer(content: RecapShareCard(summary: summary,
                                                             streakDays: sessionStore.streakDays))
        renderer.scale = 3
        shareImage = renderer.uiImage
    }
}
