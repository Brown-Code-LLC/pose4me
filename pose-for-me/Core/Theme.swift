import SwiftUI
import UIKit
import CoreText

// MARK: - Color primitives

extension Color {
    /// Hex initializer: 0xRRGGBB.
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }

    /// A color that resolves differently in light and dark mode.
    init(light: UInt32, dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            let alpha = traits.userInterfaceStyle == .dark ? darkAlpha : lightAlpha
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: alpha)
        })
    }
}

// MARK: - Design tokens (teal/green health palette, light + dark)

enum Theme {
    // Brand
    static let teal = Color(hex: 0x0d7a6f)          // primary teal
    static let tealPressed = Color(hex: 0x0a5f57)   // deep teal
    static let mint = Color(hex: 0x4ee6c1)          // bright mint
    static let mintSoft = Color(hex: 0x34c3a6)      // soft mint (gradient partner)

    /// Adaptive accent: teal in light mode, bright mint in dark mode.
    static let accent = Color(light: 0x0d7a6f, dark: 0x4ee6c1)

    // Surfaces
    static let background = Color(light: 0xf7f9f8, dark: 0x0b1512)
    static let backgroundTop = Color(light: 0xf4faf8, dark: 0x0e2620)
    static let backgroundBottom = Color(light: 0xeaf4f0, dark: 0x0b1512)
    static let card = Color(light: 0xffffff, dark: 0x132420)
    static let cardStroke = Color(light: 0xe2eae6, dark: 0x1f3a33)
    static let cardStrokeStrong = Color(light: 0xd3e0da, dark: 0x24423a)
    /// Chips, highlights, selected fills.
    static let tintFill = Color(light: 0xe3f2ec, dark: 0x4ee6c1, darkAlpha: 0.14)
    /// Ring tracks, inactive dots.
    static let track = Color(light: 0x16211e, dark: 0xeaf6f1, lightAlpha: 0.10, darkAlpha: 0.14)

    // Text
    static let textPrimary = Color(light: 0x16211e, dark: 0xeaf6f1)
    static let textStrong = Color(light: 0x12312c, dark: 0xeaf6f1)
    static let textSecondary = Color(light: 0x6d837b, dark: 0x9db8af)
    static let textTertiary = Color(light: 0x8aa39b, dark: 0x54756b)

    // Semantic
    static let warning = Color(light: 0xf59e0b, dark: 0xfbbf24)
    static let success = Color(light: 0x0d7a6f, dark: 0x34c3a6)
    static let ember = Color(hex: 0xf59e0b)         // streak flame
    static let negative = Color(hex: 0xc2410c)
    static let healthPink = Color(hex: 0xf43f5e)

    // Pose overlay (over camera video — same in both modes)
    static let skeletonLine = mint
    static let skeletonOffTarget = Color(hex: 0xfbbf24)

    // Gradients
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [mintSoft, teal],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom],
                       startPoint: .top, endPoint: .bottom)
    }

    static var healthGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xfda4af), Color(hex: 0xf43f5e)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Glow shadow color for primary CTAs.
    static let ctaGlow = Color(hex: 0x0d7a6f, alpha: 0.34)

    // Shape
    static let cardRadius: CGFloat = 17
    static let buttonRadius: CGFloat = 13
}

// MARK: - Typography (Sora display / Outfit body)

enum AppFonts {
    /// Registers the bundled variable fonts. Call once at app start.
    static func registerAll() {
        for name in ["Sora-Variable", "Outfit-Variable"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    /// Sora — headlines, timers, big numbers (600–800).
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom("Sora", size: size).weight(weight)
    }

    /// Outfit — body, labels, buttons (400–600).
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Outfit", size: size).weight(weight)
    }

    // Semantic styles used across the app.
    static var appLargeTitle: Font { display(30, .heavy) }
    static var appTitle: Font { display(25, .bold) }
    static var appTitle2: Font { display(21, .bold) }
    static var appTitle3: Font { display(18, .bold) }
    static var appHeadline: Font { .body(17, .semibold) }
    static var appBody: Font { .body(17) }
    static var appSubheadline: Font { .body(15, .medium) }
    static var appFootnote: Font { .body(13, .medium) }
    static var appCaption: Font { .body(12, .medium) }
    static var appCaption2: Font { .body(11, .medium) }
}

// MARK: - Backgrounds & containers

/// Full-screen app background: quiet vertical gradient per theme spec.
struct AppBackground: View {
    var body: some View {
        Theme.backgroundGradient
            .ignoresSafeArea()
    }
}

/// Card container: white/deep-green surface, 16–18pt radius, hairline border,
/// minimal elevation in light mode.
struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                            .strokeBorder(Theme.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardStyle(padding: padding)) }

    /// Dark glass overlay used for HUD elements over camera video.
    func glass(cornerRadius: CGFloat = Theme.cardRadius) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(hex: 0x0b1512, alpha: 0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

// MARK: - Buttons

/// Primary CTA: soft-mint -> teal gradient, 13pt radius, teal glow.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body(17, .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                    .fill(configuration.isPressed
                          ? AnyShapeStyle(Theme.tealPressed)
                          : AnyShapeStyle(Theme.brandGradient))
            )
            .shadow(color: Theme.ctaGlow, radius: 12, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Secondary: tinted fill, no glow.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body(17, .medium))
            .foregroundStyle(Theme.accent)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                    .fill(Theme.tintFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                            .strokeBorder(Theme.cardStroke, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
