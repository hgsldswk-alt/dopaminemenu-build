import SwiftUI

struct WidgetGuide: View {
    let back: () -> Void
    let choose: (Budget?) -> Void

    var body: some View {
        PageLayout {
            PaperButton(key: "common.menu", id: "widgets.back", action: back)
        } content: {
            HeroCard(symbol: "square.grid.2x2") {
                Paper.heading(L.t("widget.guide")).accessibilityIdentifier("widgets.title")
            }
            Text(L.t("widget.instructions")).foregroundStyle(Paper.secondary)
            Text(L.t("widget.home")).sectionHeading()
            HStack(spacing: 8) {
                ForEach(Budget.allCases) { budget in
                    BudgetTile(budget: budget, isSelected: false) { choose(budget) }
                }
            }
            PaperButton(key: "widget.remembered", id: "widgets.remembered", style: .outline,
                        symbol: "arrow.clockwise") { choose(nil) }
            Text(L.t("widget.lock")).sectionHeading()
            PaperButton(key: "widget.quick", id: "widgets.quick", style: .outline,
                        symbol: "timer") { choose(.five) }
            Text(L.t("widget.privacy")).font(.footnote).foregroundStyle(Paper.secondary)
        } footer: {}
    }
}
