import Combine
import Foundation
import StoreKit

@MainActor
final class Purchases: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var busy = false
    @Published var error: String?

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    func listen(model: AppModel) async {
        guard !Launch.uiTesting else { return }
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update, isOurs(transaction) else { continue }
            apply(transaction, model: model)
            await transaction.finish()
        }
    }

    func refresh(model: AppModel, clearMissing: Bool = false) async {
        guard !Launch.uiTesting else { return }
        for id in [Launch.proID, Launch.trialID] {
            if let latest = await Transaction.latest(for: id) {
                if case .verified(let transaction) = latest, isOurs(transaction) {
                    apply(transaction, model: model)
                }
            } else if clearMissing && id == Launch.proID {
                var current = model.entitlement
                current.purchasedPro = false
                model.updateEntitlement(current)
            }
        }
    }

    func loadProducts(retry: Bool = false) async {
        guard !Launch.uiTesting, (products.isEmpty || retry), !busy else { return }
        busy = true
        defer { busy = false }
        do {
            products = try await Product.products(for: [Launch.proID, Launch.trialID])
                .filter { $0.type == .nonConsumable }
            if products.isEmpty { self.error = "pro.unavailable" }
        } catch {
            self.error = "pro.unavailable"
        }
    }

    func purchase(_ id: String, model: AppModel) async {
        guard !busy, !Launch.uiTesting else { return }
        error = nil
        if product(id) == nil { await loadProducts(retry: true) }
        guard !busy else { return }
        guard let offering = product(id) else {
            self.error = "pro.unavailable"
            return
        }
        busy = true
        defer { busy = false }
        do {
            switch try await offering.purchase() {
            case .success(.verified(let transaction)) where isOurs(transaction):
                apply(transaction, model: model)
                await transaction.finish()
            case .pending:
                self.error = "pro.pending"
            case .userCancelled:
                break
            default:
                self.error = "pro.unverified"
            }
        } catch {
            self.error = "pro.unavailable"
        }
    }

    func restore(model: AppModel) async {
        guard !busy, !Launch.uiTesting else { return }
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refresh(model: model, clearMissing: true)
            self.error = model.entitlement.purchasedPro || model.entitlement.trialClaimedAt != nil
                ? "pro.restored" : "pro.none"
        } catch {
            self.error = "pro.unavailable"
        }
    }

    private func isOurs(_ transaction: Transaction) -> Bool {
        transaction.productType == .nonConsumable &&
        (transaction.productID == Launch.proID || transaction.productID == Launch.trialID)
    }

    private func apply(_ transaction: Transaction, model: AppModel) {
        var updated = model.entitlement
        let revoked = transaction.revocationDate != nil || transaction.isUpgraded
        if transaction.productID == Launch.proID {
            updated.purchasedPro = !revoked
        } else {
            updated.applyTrial(originalDate: transaction.originalPurchaseDate, revoked: revoked)
        }
        model.updateEntitlement(updated)
    }
}
