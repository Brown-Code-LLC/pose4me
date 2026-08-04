import AppIntents
import SwiftUI
import WidgetKit

/// Control Center / Lock Screen button (iOS 18+): opens the app straight into
/// a stretch by routing through the pose4me:// deep link RootView already
/// handles — same path as a widget tap.
struct LaunchStretchControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a Stretch"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "pose4me://stretch")!))
    }
}

struct StartStretchControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.browncode.pose4me.startstretch") {
            ControlWidgetButton(action: LaunchStretchControlIntent()) {
                Label("Start Stretch", systemImage: "figure.flexibility")
            }
        }
        .displayName("Start Stretch")
        .description("Open Pose4Me and start your next stretch.")
    }
}
