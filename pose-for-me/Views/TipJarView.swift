import Combine
import SwiftUI
import StoreKit

/// "Buy me a coffee" — Pose4Me is free for everyone; this is the only money
/// surface in the app, and it's entirely optional.
struct TipJarView: View {
    @EnvironmentObject private var tipJar: TipJar
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body(15, .bold))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(10)
                                .background(Theme.tintFill, in: Circle())
                        }
                        .accessibilityIdentifier("tipjar.close")
                    }
                    .padding(.top, 14)

                    if tipJar.justTipped {
                        thanks
                    } else {
                        content
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.top, 18)

            VStack(spacing: 8) {
                Overline("Support Pose4Me")
                Text("Buy me a coffee")
                    .font(.appTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("Pose4Me is free for everyone — every pose, every feature, no subscriptions. It's built by one person. If it helps you feel better at your desk, a coffee keeps it going.")
                    .font(.appSubheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)

            VStack(spacing: 10) {
                ForEach(TipJar.tiers) { tier in
                    tierRow(tier)
                }
            }
            .padding(.top, 28)

            if !tipJar.storeConfigured {
                Text("Tipping goes live once the App Store listing is set up. Thanks for wanting to — that already means a lot.")
                    .font(.appCaption)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
            }
        }
    }

    private func tierRow(_ tier: TipJar.Tier) -> some View {
        let product = tipJar.product(for: tier)
        return Button {
            guard let product else { return }
            Task { await tipJar.tip(product) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: tier.symbol)
                    .font(.appHeadline)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30)
                Text(tier.name)
                    .font(.appHeadline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if tipJar.purchaseInFlight {
                    ProgressView().tint(Theme.accent)
                } else {
                    Text(product?.displayPrice ?? tier.fallbackPrice)
                        .font(.display(15, .semibold))
                        .foregroundStyle(product == nil && !tipJar.displayPreview
                                         ? Theme.textTertiary : Theme.accent)
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .card(padding: 0)
        .disabled(product == nil || tipJar.purchaseInFlight)
        .opacity(product == nil && !tipJar.displayPreview ? 0.65 : 1)
    }

    private var thanks: some View {
        VStack(spacing: 0) {
            Image(systemName: "heart.fill")
                .font(.system(size: 34))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Theme.teal, in: Circle())
                .padding(.top, 40)

            Text("Thank you")
                .font(.appTitle)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 20)

            Text("Seriously — you just funded the next stretch. Enjoy the app, and keep moving.")
                .font(.appSubheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            Button("Done") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 30)
        }
        .frame(maxWidth: .infinity)
    }
}
