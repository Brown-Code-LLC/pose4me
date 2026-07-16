import SwiftUI

/// Pose4Me design system: colors, gradients, and reusable styles.
enum Theme {
    // Palette — deep space background with an energetic aurora accent.
    static let backgroundTop = Color(red: 0.05, green: 0.06, blue: 0.12)
    static let backgroundBottom = Color(red: 0.09, green: 0.10, blue: 0.20)
    static let card = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.10)

    static let aurora1 = Color(red: 0.31, green: 0.89, blue: 0.76)   // mint
    static let aurora2 = Color(red: 0.33, green: 0.62, blue: 1.00)   // azure
    static let aurora3 = Color(red: 0.72, green: 0.46, blue: 1.00)   // violet
    static let ember = Color(red: 1.00, green: 0.58, blue: 0.33)     // streak flame
    static let success = Color(red: 0.36, green: 0.90, blue: 0.55)
    static let warning = Color(red: 1.00, green: 0.78, blue: 0.35)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)

    static var auroraGradient: LinearGradient {
        LinearGradient(colors: [aurora1, aurora2, aurora3],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom],
                       startPoint: .top, endPoint: .bottom)
    }

    static var skeletonGradient: LinearGradient {
        LinearGradient(colors: [aurora1, aurora2],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// Full-screen app background.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.backgroundGradient
            // Soft aurora glow blobs for depth.
            Circle()
                .fill(Theme.aurora2.opacity(0.18))
                .frame(width: 380, height: 380)
                .blur(radius: 90)
                .offset(x: -140, y: -280)
            Circle()
                .fill(Theme.aurora3.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 160, y: 300)
        }
        .ignoresSafeArea()
    }
}

/// Frosted card container used across screens.
struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Theme.cardStroke, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardStyle(padding: padding)) }
}

/// Primary gradient pill button.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Theme.auroraGradient, in: Capsule())
            .shadow(color: Theme.aurora2.opacity(0.45), radius: 14, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Secondary translucent pill button.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.medium))
            .foregroundStyle(Theme.textPrimary)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.09), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
