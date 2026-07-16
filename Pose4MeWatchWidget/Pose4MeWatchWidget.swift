import WidgetKit
import SwiftUI

struct WatchStretchEntry: TimelineEntry {
    let date: Date
    let nextFire: Date?
    let streakDays: Int
}

struct WatchStretchProvider: TimelineProvider {
    static let appGroupID = "group.pose-for-me.shared"

    func placeholder(in context: Context) -> WatchStretchEntry {
        WatchStretchEntry(date: .now, nextFire: .now.addingTimeInterval(1800), streakDays: 4)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchStretchEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchStretchEntry>) -> Void) {
        let current = entry()
        let refresh = current.nextFire.flatMap { $0 > .now ? $0 : nil }
            ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [current], policy: .after(refresh)))
    }

    private func entry() -> WatchStretchEntry {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        return WatchStretchEntry(
            date: .now,
            nextFire: defaults?.object(forKey: "widget.nextFireDate") as? Date,
            streakDays: defaults?.integer(forKey: "widget.streakDays") ?? 0
        )
    }
}

struct WatchStretchWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchStretchEntry

    private var isDue: Bool {
        guard let nextFire = entry.nextFire else { return false }
        return nextFire <= .now
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Pose4Me", systemImage: "figure.flexibility")
                    .font(.caption2.bold())
                countdown(font: .system(size: 18, weight: .bold, design: .rounded))
                Text(isDue ? "time to stretch" : "until next stretch")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            if let next = entry.nextFire, next > .now {
                Text("🧘 Stretch \(next, style: .relative)")
            } else {
                Text("🧘 Time to stretch")
            }
        default: // accessoryCircular + corner
            VStack(spacing: 1) {
                Image(systemName: isDue ? "figure.flexibility" : "timer")
                    .font(.caption2)
                countdown(font: .system(size: 12, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .containerBackground(for: .widget) { Color.clear }
        }
    }

    @ViewBuilder
    private func countdown(font: Font) -> some View {
        if let next = entry.nextFire, next > .now {
            Text(timerInterval: Date.now...next, countsDown: true)
                .font(font)
                .monospacedDigit()
        } else if isDue {
            Text("Now!").font(font)
        } else {
            Text("—").font(font)
        }
    }
}

@main
struct Pose4MeWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchStretchWidget()
    }
}

struct WatchStretchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Pose4MeWatchCountdown", provider: WatchStretchProvider()) { entry in
            WatchStretchWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Stretch")
        .description("Countdown to your next stretch.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular,
                            .accessoryInline, .accessoryCorner])
    }
}
