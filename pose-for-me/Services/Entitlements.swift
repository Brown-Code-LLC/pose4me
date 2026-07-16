import Combine
import Foundation
import StoreKit

/// Pro subscription state, backed by StoreKit 2.
///
/// Product IDs below must be created in App Store Connect (or a .storekit config file)
/// before real purchases work. Until then `products` comes back empty and the paywall
/// falls back to a clearly-labeled developer unlock so the full app remains testable.
@MainActor
final class Entitlements: ObservableObject {
    static let monthlyID = "pose4me.pro.monthly"
    static let yearlyID = "pose4me.pro.yearly"

    @Published private(set) var isPro: Bool
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseInFlight = false

    private static let devUnlockKey = "pose4me.pro.devUnlock"
    private var updatesTask: Task<Void, Never>?

    init() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "pose4me.resetPro") {
            UserDefaults.standard.removeObject(forKey: Self.devUnlockKey)
        }
        #endif
        isPro = UserDefaults.standard.bool(forKey: Self.devUnlockKey)
        updatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                if let transaction = try? update.payloadValue {
                    await transaction.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlement()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        products = (try? await Product.products(for: [Self.monthlyID, Self.yearlyID])) ?? []
    }

    func refreshEntitlement() async {
        var active = false
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? entitlement.payloadValue,
               transaction.productID == Self.monthlyID || transaction.productID == Self.yearlyID {
                active = true
            }
        }
        if active || UserDefaults.standard.bool(forKey: Self.devUnlockKey) {
            isPro = true
        } else if !active {
            isPro = UserDefaults.standard.bool(forKey: Self.devUnlockKey)
        }
    }

    func purchase(_ product: Product) async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        guard let result = try? await product.purchase() else { return }
        if case .success(let verification) = result,
           let transaction = try? verification.payloadValue {
            await transaction.finish()
            isPro = true
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    /// Developer unlock used until App Store Connect products exist.
    func setDevUnlock(_ unlocked: Bool) {
        UserDefaults.standard.set(unlocked, forKey: Self.devUnlockKey)
        isPro = unlocked
    }
}
