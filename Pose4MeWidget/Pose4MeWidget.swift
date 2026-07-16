import WidgetKit
import SwiftUI

// MARK: - Timeline

struct StretchEntry: TimelineEntry {
    let date: Date
    let nextFire: Date?
    let streakDays: Int
    let todayCount: Int
}

struct StretchProvider: TimelineProvider {
    func placeholder(in context: Context) -> StretchEntry {
        StretchEntry(date: .now, nextFire: .now.addingTimeInterval(1800),
                     streakDays: 4, todayCount: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (StretchEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StretchEntry>) -> Void) {
        let current = entry()
        // Countdown text auto-updates via Text(timerInterval:); refresh the timeline
        // when the reminder fires (state flips to "time to stretch") or in 30 min.
        let refresh = current.nextFire.flatMap { $0 > .now ? $0 : nil }
            ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [current], policy: .after(refresh)))
    }

    private func entry() -> StretchEntry {
        let state = SharedState.load()
        return StretchEntry(date: .now, nextFire: state.nextFireDate,
                            streakDays: state.streakDays, todayCount: state.todayCount)
    }
}

// MARK: - Shared bits

private extension StretchEntry {
    var isDue: Bool {
        guard let nextFire else { return false }
        return nextFire <= .now
    }
}

private let widgetTeal = Color(red: 0x0d / 255, green: 0x7a / 255, blue: 0x6f / 255)
private let widgetMint = Color(red: 0x4e / 255, green: 0xe6 / 255, blue: 0xc1 / 255)
private let widgetEmber = Color(red: 0xf5 / 255, green: 0x9e / 255, blue: 0x0b / 255)

private struct CountdownText: View {
    let entry: StretchEntry
    var font: Font

    var body: some View {
        if let nextFire = entry.nextFire, nextFire > .now {
            Text(timerInterval: Date.now...nextFire, countsDown: true)
                .font(font)
                .monospacedDigit()
                .multilineTextAlignment(.center)
        } else if entry.isDue {
            Text("Now!")
                .font(font)
        } else {
            Text("—")
                .font(font)
        }
    }
}

// MARK: - Home screen widget

struct StretchCountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StretchEntry

    var body: some View {
        switch family {
        case .systemMedium: medium
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        default: small
        }
    }

    private var small: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "figure.flexibility")
                    .font(.caption)
                    .foregroundStyle(widgetMint)
                Spacer()
                if entry.streakDays > 0 {
                    Label("\(entry.streakDays)", systemImage: "flame.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(widgetEmber)
                }
            }
            Spacer()
            CountdownText(entry: entry, font: .system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(entry.isDue ? "time to stretch" : "until next stretch")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .containerBackground(for: .widget) { backgroundGradient }
        .widgetURL(URL(string: "pose4me://stretch"))
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pose4Me")
                    .font(.caption.bold())
                    .foregroundStyle(widgetMint)
                CountdownText(entry: entry, font: .system(size: 34, weight: .bold, design: .rounded))
                Text(entry.isDue ? "time to stretch" : "until next stretch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                Label("\(entry.streakDays) day streak", systemImage: "flame.fill")
                    .font(.caption.bold())
                    .foregroundStyle(widgetEmber)
                Label("\(entry.todayCount) today", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(widgetMint)
                Text("Tap to stretch")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) { backgroundGradient }
        .widgetURL(URL(string: "pose4me://stretch"))
    }

    private var backgroundGradient: some View {
        LinearGradient(colors: [Color(red: 0.055, green: 0.15, blue: 0.125),
                                Color(red: 0.043, green: 0.082, blue: 0.071)],
                       startPoint: .top, endPoint: .bottom)
    }

    // MARK: Lock screen / accessory

    private var circular: some View {
        VStack(spacing: 1) {
            Image(systemName: entry.isDue ? "figure.flexibility" : "timer")
                .font(.caption)
            CountdownText(entry: entry, font: .system(size: 13, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "pose4me://stretch"))
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Pose4Me", systemImage: "figure.flexibility")
                .font(.caption2.bold())
            CountdownText(entry: entry, font: .system(size: 18, weight: .bold, design: .rounded))
            Text(entry.isDue ? "time to stretch" : "until next stretch")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "pose4me://stretch"))
    }

    private var inline: some View {
        Group {
            if let nextFire = entry.nextFire, nextFire > .now {
                Text("🧘 Stretch \(nextFire, style: .relative)")
            } else if entry.isDue {
                Text("🧘 Time to stretch")
            } else {
                Text("🧘 Pose4Me")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "pose4me://stretch"))
    }
}

struct StretchCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Pose4MeCountdown", provider: StretchProvider()) { entry in
            StretchCountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Stretch")
        .description("Countdown to your next stretch, streak and today's total.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct Pose4MeWidgetBundle: WidgetBundle {
    var body: some Widget {
        StretchCountdownWidget()
    }
}
