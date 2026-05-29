import Foundation
import StoreKit

struct CoinPack: Identifiable, CaseIterable {
    let slug: String
    let name: String
    let coins: Int
    let badge: String?

    var id: String { productID }
    var productID: String { "com.markwebber.letterraiders.coins.\(slug)" }

    static let allCases: [CoinPack] = [
        .init(slug: "pocket", name: "Pocket Change", coins: 1_500, badge: nil),
        .init(slug: "cadet", name: "Cadet Pack", coins: 5_500, badge: "STARTER"),
        .init(slug: "captain", name: "Captain Pack", coins: 12_000, badge: "POPULAR"),
        .init(slug: "commander", name: "Commander Pack", coins: 30_000, badge: "BEST VALUE"),
        .init(slug: "admiral", name: "Admiral Vault", coins: 65_000, badge: "BIGGEST"),
    ]

    static func pack(for productID: String) -> CoinPack? {
        allCases.first { $0.productID == productID }
    }
}

@MainActor
final class CoinStore: ObservableObject {
    static let shared = CoinStore()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var purchasingProductID: String?
    @Published var message: String?

    private let deliveredTransactionsKey = "deliveredCoinPurchaseTransactions"
    private var updatesTask: Task<Void, Never>?

    private init() {}

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
        Task { await loadProducts() }
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await Product.products(for: CoinPack.allCases.map(\.productID))
            products = fetched.sorted { lhs, rhs in
                packIndex(for: lhs.id) < packIndex(for: rhs.id)
            }
            message = products.isEmpty ? "Coin packs are unavailable right now." : nil
        } catch {
            message = "Couldn't load coin packs. Check your connection and try again."
        }
    }

    func product(for pack: CoinPack) -> Product? {
        products.first { $0.id == pack.productID }
    }

    func purchase(_ pack: CoinPack) async {
        if products.isEmpty {
            await loadProducts()
        }
        guard let product = product(for: pack) else {
            message = "That coin pack is unavailable right now."
            return
        }

        purchasingProductID = product.id
        defer { purchasingProductID = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                deliverCoins(for: transaction)
                await transaction.finish()
                message = "Coins added."
            case .pending:
                message = "Purchase pending approval."
            case .userCancelled:
                break
            @unknown default:
                message = "Purchase couldn't be completed."
            }
        } catch {
            message = "Purchase couldn't be completed."
        }
    }

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            deliverCoins(for: transaction)
            await transaction.finish()
        } catch {
            message = "A purchase couldn't be verified."
        }
    }

    private func deliverCoins(for transaction: Transaction) {
        guard let pack = CoinPack.pack(for: transaction.productID) else { return }
        var delivered = deliveredTransactionIDs
        let transactionID = String(transaction.id)
        guard !delivered.contains(transactionID) else { return }
        Hangar.awardCoins(pack.coins)
        delivered.insert(transactionID)
        deliveredTransactionIDs = delivered
    }

    private var deliveredTransactionIDs: Set<String> {
        get {
            let ids = UserDefaults.standard.stringArray(forKey: deliveredTransactionsKey) ?? []
            return Set(ids)
        }
        set {
            UserDefaults.standard.set(Array(newValue).sorted(), forKey: deliveredTransactionsKey)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    private func packIndex(for productID: String) -> Int {
        CoinPack.allCases.firstIndex { $0.productID == productID } ?? Int.max
    }

    private enum StoreError: Error {
        case failedVerification
    }
}
