import StoreKit

/// One-time "Support Keyglot" purchase via StoreKit 2. The app is fully usable without it; buying
/// just removes the periodic reminder. Caches the entitlement into the App Group so the extensions
/// stop counting uses once purchased.
@MainActor
final class StoreManager: ObservableObject {

    static let productID = "it.izzonline.keyglot.support"

    @Published var product: Product?
    @Published private(set) var isSupporter = AppGroupStorage.shared.isSupporter

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = observeTransactions()
    }

    deinit { updatesTask?.cancel() }

    /// Load the product and refresh the current entitlement.
    func load() async {
        product = try? await Product.products(for: [Self.productID]).first
        await refresh()
    }

    /// Re-evaluate ownership from StoreKit's current entitlements.
    func refresh() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        setSupporter(owned)
    }

    func purchase() async {
        guard let product else { return }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result,
               case .verified(let transaction) = verification {
                await transaction.finish()
                setSupporter(true)
            }
        } catch {
            // User cancelled or the purchase failed — leave state unchanged.
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    private func setSupporter(_ value: Bool) {
        isSupporter = value
        AppGroupStorage.shared.isSupporter = value
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    if transaction.productID == Self.productID {
                        await self?.refresh()
                    }
                }
            }
        }
    }
}
