import SwiftUI
import WidgetKit

struct MenuWidgetEntry: TimelineEntry {
    let date: Date
    let budget: Budget
}

struct MenuWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MenuWidgetEntry {
        MenuWidgetEntry(date: .now, budget: .five)
    }

    func getSnapshot(in context: Context, completion: @escaping (MenuWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MenuWidgetEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .never))
    }

    private func entry() -> MenuWidgetEntry {
        MenuWidgetEntry(date: .now, budget: WidgetSnapshot.read())
    }
}

struct MenuWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MenuWidgetEntry

    var body: some View {
        content
            .containerBackground(for: .widget) { DesignPalette.background }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label(L.t("widget.quick"), systemImage: "timer").font(.headline)
                Text(L.t("widget.start")).font(.caption)
            }
            .widgetURL(WidgetRoute.timed(.five).url)
        case .systemMedium:
            VStack(alignment: .leading, spacing: 10) {
                Text(L.t("widget.choose")).font(.headline)
                HStack {
                    ForEach(Budget.allCases) { budget in
                        Link(destination: WidgetRoute.timed(budget).url) {
                            VStack(spacing: 2) {
                                Image(systemName: budget.tileSymbol).font(.caption.weight(.semibold))
                                    .accessibilityHidden(true)
                                Text(budget.rawValue, format: .number)
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .monospacedDigit()
                                Text(L.t("unit.min")).font(.caption)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(budget.tileColor, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .accessibilityLabel(L.f("unit.minutes", budget.rawValue))
                    }
                }
            }
            .foregroundStyle(DesignPalette.ink)
            .widgetURL(WidgetRoute.remembered.url)
        default:
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: "timer")
                    .font(.headline).frame(width: 34, height: 34)
                    .background(entry.budget.tileColor, in: RoundedRectangle(cornerRadius: 11))
                    .accessibilityHidden(true)
                Text(L.t("widget.choose")).font(.headline)
                Text(L.f("unit.minutes", entry.budget.rawValue))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(DesignPalette.ink)
            .widgetURL(WidgetRoute.remembered.url)
        }
    }
}

@main
struct MenuWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DopamineMenuWidget", provider: MenuWidgetProvider()) { entry in
            MenuWidgetView(entry: entry)
        }
        .configurationDisplayName(L.t("app.name"))
        .description(L.t("widget.description"))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
