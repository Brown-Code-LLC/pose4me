import Combine
import SwiftUI
import StoreKit

/// Pro subscription paywall. Uses real StoreKit products when App Store Connect is
/// configured; until then it shows placeholder pricing with a clearly-labeled
/// developer unlock so the whole app remains testable.
struct PaywallView: View {
    @EnvironmentObject private var entitlements: Entitlements
    @Environment(\.dismiss) private var dismiss

    @State private var selectedYearly = true
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 22) {
                    header
                    features
                    planPicker
                    purchaseButton
                    footer
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body(15, .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            GuideFigureView(spec: PoseSpec(leftUpperArm: -172, leftForearm: -176,
                                           rightUpperArm: 172, rightForearm: 176))
                .frame(width: 120, height: 160)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)

            Text("Pose4Me Pro")
                .font(.display(32, .heavy))
                .foregroundStyle(Theme.brandGradient)
            Text("Your body works all day. Give it a coach.")
                .font(.appSubheadline)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow("figure.mixed.cardio", "Full stretch library",
                       "Every pose, every category, new drops monthly")
            featureRow("camera.viewfinder", "Form coaching",
                       "Strict-mode pose tracking with limb-level cues")
            featureRow("chart.bar.fill", "Unlimited history",
                       "Every session and form score, forever")
            featureRow("bell.badge.fill", "Multiple schedules",
                       "Different rhythms for work days and weekends")
        }
        .card(padding: 18)
    }

    private func featureRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.brandGradient)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body(15, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.appCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var planPicker: some View {
        HStack(spacing: 12) {
            planCard(title: "Yearly", price: yearlyPrice, badge: "SAVE 52%",
                     sub: "7-day free trial", isSelected: selectedYearly) {
                selectedYearly = true
            }
            planCard(title: "Monthly", price: monthlyPrice, badge: nil,
                     sub: "Cancel anytime", isSelected: !selectedYearly) {
                selectedYearly = false
            }
        }
    }

    private func planCard(title: String, price: String, badge: String?, sub: String,
                          isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }
            Haptics.tap()
        } label: {
            VStack(spacing: 6) {
                if let badge {
                    Text(badge)
                        .font(.body(10, .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.warning, in: Capsule())
                }
                Text(title)
                    .font(.appHeadline)
                    .foregroundStyle(Theme.textPrimary)
                Text(price)
                    .font(.appTitle3)
                    .foregroundStyle(Theme.textPrimary)
                Text(sub)
                    .font(.appCaption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(isSelected ? AnyShapeStyle(Theme.brandGradient)
                                                     : AnyShapeStyle(Theme.cardStroke),
                                          lineWidth: isSelected ? 2 : 1)
                    )
            )
            .scaleEffect(isSelected ? 1.03 : 1)
        }
        .buttonStyle(.plain)
    }

    private var purchaseButton: some View {
        Button {
            Task {
                if let product = selectedProduct {
                    await entitlements.purchase(product)
                } else {
                    // No App Store Connect products yet — developer unlock.
                    entitlements.setDevUnlock(true)
                }
                if entitlements.isPro { dismiss() }
            }
        } label: {
            if entitlements.purchaseInFlight {
                ProgressView().tint(.black)
            } else {
                Text(selectedYearly ? "Start free trial" : "Subscribe")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(entitlements.purchaseInFlight)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button("Restore purchases") {
                Task { await entitlements.restorePurchases() }
            }
            .font(.appFootnote)
            .foregroundStyle(Theme.textSecondary)

            if entitlements.products.isEmpty {
                Text("Store products not configured yet — the button above uses a local developer unlock.")
                    .font(.appCaption2)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var selectedProduct: Product? {
        let id = selectedYearly ? Entitlements.yearlyID : Entitlements.monthlyID
        return entitlements.products.first { $0.id == id }
    }

    private var yearlyPrice: String {
        entitlements.products.first { $0.id == Entitlements.yearlyID }?.displayPrice ?? "$39.99/yr"
    }

    private var monthlyPrice: String {
        entitlements.products.first { $0.id == Entitlements.monthlyID }?.displayPrice ?? "$6.99/mo"
    }
}
