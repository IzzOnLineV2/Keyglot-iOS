import Foundation
import StoreKit

/// StoreKit 2 subscription for KeyGlot mode ("Keyglot Pro"). Loads the products, tracks whether
/// the user has an active entitlement, and exposes the signed transaction (JWS) so the app can
/// exchange it with the KeyGlot backend for a session token.
///
/// Separate from `StoreManager` (which handles the optional one-time "support" tip). Prices come
/// from App Store Connect / the local `.storekit` file — never hardcoded here.
@MainActor
final class SubscriptionManager: ObservableObject {

    @Published private(set) var products: [Product] = []
    @Published private(set) var isSubscribed = false
    @Published private(set) var isLoading = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refresh()
            }
        }
    }

    deinit { updatesTask?.cancel() }

    /// Load products (sorted monthly → yearly by price) and refresh entitlement.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        let loaded = (try? await Product.products(for: Configuration.subscriptionProductIDs)) ?? []
        products = loaded.sorted { $0.price < $1.price }
        await refresh()
    }

    /// Recompute `isSubscribed` from StoreKit's current entitlements.
    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result,
                  Configuration.subscriptionProductIDs.contains(t.productID),
                  t.revocationDate == nil,
                  (t.expirationDate ?? .distantFuture) > Date() else { continue }
            active = true
        }
        isSubscribed = active
    }

    /// Purchase a subscription. Returns true if it completed (verified).
    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        guard case .success(let verification) = result,
              case .verified(let transaction) = verification else { return false }
        await transaction.finish()
        await refresh()
        return true
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    /// The signed JWS of the active subscription entitlement, to send to the KeyGlot backend.
    /// `nil` if there's no active, verified subscription.
    func currentEntitlementJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result,
                  Configuration.subscriptionProductIDs.contains(t.productID),
                  t.revocationDate == nil else { continue }
            return result.jwsRepresentation
        }
        return nil
    }
}
