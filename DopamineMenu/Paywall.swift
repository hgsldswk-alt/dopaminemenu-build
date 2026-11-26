import StoreKit
import SwiftUI

@MainActor
struct Paywall: View {
    @ObservedObject var model: AppModel
    @ObservedObject var purchases: Purchases
    let back: () -> Void

    var body: some View {
        PageLayout {
            PaperButton(key: "common.menu", id: "pro.close", action: back)
        } content: {
            HeroCard(symbol: "star") {
                Paper.heading(L.t("pro.title")).accessibilityIdentifier("paywall.title")
            }
            Text(L.t("pro.explainer")).foregroundStyle(Paper.secondary)
            VStack(spacing: 8) {
                feature("pro.filters", symbol: "line.3.horizontal.decrease.circle", color: Paper.mint)
                feature("pro.recap", symbol: "calendar", color: Paper.yellow)
                feature("pro.layouts", symbol: "rectangle.on.rectangle", color: Paper.blue)
            }
            if model.entitlement.purchasedPro {
                StatusPill(text: L.t("pro.owned"), color: Paper.mint.opacity(0.45))
            } else if model.hasPro {
                Text(L.t("pro.ends")).font(.headline)
                Text(model.entitlement.trialEnd, format: .dateTime.year().month().day())
                    .accessibilityIdentifier("pro.expiry")
            } else {
                StatusPill(text: L.t("pro.expired"), color: Paper.tint).accessibilityIdentifier("pro.expired")
            }
            Text(L.t("pro.free")).foregroundStyle(Paper.secondary).font(.footnote)
            if let error = purchases.error {
                Text(L.t(error)).foregroundStyle(Paper.emphasis).accessibilityIdentifier("pro.status")
            }
        } footer: {
            if !model.entitlement.purchasedPro {
                buyButton.disabled(purchases.busy)
                if model.hasPro, model.entitlement.trialClaimedAt == nil {
                    PaperButton(key: "pro.claim", id: "pro.trial", style: .outline, symbol: "clock") {
                        Task { await purchases.purchase(Launch.trialID, model: model) }
                    }
                    .disabled(purchases.busy)
                    Text(L.t("pro.claimNote")).foregroundStyle(Paper.secondary).font(.footnote)
                }
            }
            PaperButton(key: "pro.restore", id: "pro.restore", style: .outline, symbol: "arrow.clockwise") {
                Task { await purchases.restore(model: model) }
            }
            .disabled(purchases.busy)
        }
        .task { await purchases.loadProducts() }
    }

    private func feature(_ key: String, symbol: String, color: Color) -> some View {
        IconRow(symbol: symbol, color: color) {
            Text(L.t(key))
        } detail: {
            EmptyView()
        } trailing: {
            EmptyView()
        }
    }

    private var buyButton: some View {
        PrimaryButton(title: purchases.product(Launch.proID).map { L.f("pro.buyPrice", $0.displayPrice) }
                      ?? (Launch.uiTesting ? L.f("pro.buyPrice", "$4.99") : L.t("pro.buy")),
                      symbol: "lock.open") {
            Task { await purchases.purchase(Launch.proID, model: model) }
        }
        .accessibilityIdentifier("pro.buy")
    }
}
