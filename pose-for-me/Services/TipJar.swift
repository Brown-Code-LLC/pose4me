import Combine
import Foundation
import StoreKit

/// "Buy me a coffee" support — the app is free for everyone; tips are optional
/// consumable in-app purchases (App Store rules require digital tips to go
/// through IAP rather than external donation links).
///
/// The three products below must be created as CONSUMABLES in App Store Connect.
/// Until then `products` stays empty and the tip jar shows placeholder tiers
/// with purchasing disabled.
@MainActor
final class TipJar: ObservableObject {
    struct Tier: Identifiable {
        let id: String
        let name: String
        let symbol: String
        let fallbackPrice: String
    }

    static let tiers: [Tier] = [
        Tier(id: "pose4me.tip.espresso", name: "Espresso", symbol: "cup.and.saucer.fill", fallbackPrice: "$1.99"),
        Tier(id: "pose4me.tip.latte", name: "Latte", symbol: "cup.and.saucer.fill", fallbackPrice: "$4.99"),
        Tier(id: "pose4me.tip.carafe", name: "Whole carafe", symbol: "mug.fill", fallbackPrice: "$9.99"),
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseInFlight = false
    /// Set briefly after a successful tip so the UI can say thanks.
    @Published var justTipped = false

    /// Lifetime count of coffees bought, persisted for a quiet thank-you in Settings.
    @Published private(set) var totalTips: Int

    private static let tipCountKey = "pose4me.tips.count"
    private var updatesTask: Task<Void, Never>?

    nonisolated deinit {}

    init() {
        totalTips = UserDefaults.standard.integer(forKey: Self.tipCountKey)
        updatesTask = Task { [weak self] in
            // Finish any consumable transactions that complete out-of-band.
            for await update in StoreKit.Transaction.updates {
                if let transaction = try? update.payloadValue {
                    await transaction.finish()
                    await self?.recordTip()
                }
            }
        }
        Task { await loadProducts() }
    }

    func loadProducts() async {
        let ids = Self.tiers.map(\.id)
        products = ((try? await Product.products(for: ids)) ?? [])
            .sorted { $0.price < $1.price }
    }

    func product(for tier: Tier) -> Product? {
        products.first { $0.id == tier.id }
    }

    var storeConfigured: Bool { !products.isEmpty || displayPreview }

    /// DEBUG screenshot aid (`-pose4me.mockStore YES`): renders tiers in their live
    /// enabled style with fallback prices. Purchasing still requires real products.
    var displayPreview: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "pose4me.mockStore")
        #else
        false
        #endif
    }

    func tip(_ product: Product) async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        guard let result = try? await product.purchase() else { return }
        if case .success(let verification) = result,
           let transaction = try? verification.payloadValue {
            await transaction.finish()
            recordTip()
        }
    }

    private func recordTip() {
        totalTips += 1
        UserDefaults.standard.set(totalTips, forKey: Self.tipCountKey)
        justTipped = true
        Haptics.success()
    }
}
