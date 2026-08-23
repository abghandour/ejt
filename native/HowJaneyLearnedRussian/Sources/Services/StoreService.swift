import Observation
import StoreKit

/// StoreKit 2 subscription state. `isPremium` gates languages beyond the
/// default, festivus themes, and cloud sync — adjust gates in AppModel.
@Observable
final class StoreService {
    static let subscriptionGroupID = "21534001"
    static let productIDs = [
        "com.mokotti-solutions.howjaneylearnedrussian.premium.monthly",
        "com.mokotti-solutions.howjaneylearnedrussian.premium.yearly",
    ]

    private(set) var isPremium = false
    private(set) var products: [Product] = []

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
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
        products = (try? await Product.products(for: Self.productIDs)) ?? []
    }

    func refreshEntitlement() async {
        var premium = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               Self.productIDs.contains(transaction.productID) {
                premium = true
            }
        }
        isPremium = premium
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }
}
