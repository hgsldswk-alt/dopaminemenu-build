import SwiftUI

enum Paper {
    static let background = DesignPalette.background
    static let surface = DesignPalette.surface
    static let ink = DesignPalette.ink
    static let secondary = Color(red: 99/255, green: 92/255, blue: 84/255)
    static let line = Color(red: 232/255, green: 225/255, blue: 214/255)
    static let accent = DesignPalette.accent
    static let emphasis = Color(red: 130/255, green: 31/255, blue: 23/255)
    static let tint = Color(red: 254/255, green: 231/255, blue: 224/255)
    static let mint = DesignPalette.mint
    static let yellow = DesignPalette.yellow
    static let blue = DesignPalette.blue
    static let heroGradient = LinearGradient(colors: [accent.opacity(0.40), tint, surface],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)

    static func heading(_ title: String) -> some View {
        Text(title)
            .font(.title2.bold())
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    func paperCard(fill: Color = Paper.surface) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: Paper.ink.opacity(0.07), radius: 12, y: 4)
    }

    func paperField() -> some View {
        padding(12)
            .frame(minHeight: 48)
            .background(Paper.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Paper.line) }
    }

    func sectionHeading() -> some View {
        font(.headline).foregroundStyle(Paper.secondary).accessibilityAddTraits(.isHeader)
    }
}

struct SymbolBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 38
    var circular = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(Paper.ink)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: circular ? size / 2 : size * 0.30))
            .accessibilityHidden(true)
    }
}

struct HeroCard<Content: View>: View {
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
            EmptyIllustration(symbol: symbol)
        }
        .padding(16)
        .background(Paper.heroGradient, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Paper.ink.opacity(0.07), radius: 12, y: 4)
    }
}

struct IconTile: View {
    let key: String
    let id: String
    let symbol: String
    let color: Color
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                SymbolBadge(symbol: symbol, color: color, size: 36, circular: true)
                Text(L.t(key))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .paperCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityIdentifier(id)
    }
}

struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Paper.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color, in: Capsule())
    }
}

struct IconRow<Title: View, Detail: View, Trailing: View>: View {
    let symbol: String
    let color: Color
    @ViewBuilder let title: Title
    @ViewBuilder let detail: Detail
    @ViewBuilder let trailing: Trailing
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))
        layout {
            HStack(spacing: 10) {
                SymbolBadge(symbol: symbol, color: color)
                VStack(alignment: .leading, spacing: 3) {
                    title.font(.body.weight(.semibold))
                    detail.font(.caption).foregroundStyle(Paper.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 6) { trailing }
        }
        .padding(10)
        .frame(minHeight: 60)
        .paperCard()
        .contentShape(Rectangle())
    }
}

struct EmptyIllustration: View {
    let symbol: String

    var body: some View {
        ZStack {
            SymbolBadge(symbol: symbol, color: Paper.accent, size: 53)
                .rotationEffect(.degrees(-8))
            SymbolBadge(symbol: "sparkle", color: Paper.yellow, size: 21, circular: true)
                .offset(x: 26, y: -24)
            SymbolBadge(symbol: "leaf.fill", color: Paper.mint, size: 23, circular: true)
                .offset(x: -25, y: 22)
        }
        .frame(width: 76, height: 72)
        .accessibilityHidden(true)
    }
}

struct EmptyState<Content: View>: View {
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 12) {
            EmptyIllustration(symbol: symbol)
            content
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(Paper.secondary)
        .padding(16)
        .frame(maxWidth: .infinity)
        .paperCard()
    }
}

struct PrimaryButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).accessibilityHidden(true)
                Text(title).fixedSize(horizontal: false, vertical: true)
            }
            .font(.title3.bold())
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(contrast == .increased ? Paper.emphasis : Paper.accent,
                        in: RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
    }
}

struct PaperPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.48)
    }
}

struct PaperButton: View {
    enum Style { case primary, outline, text }
    let key: String
    let id: String
    var style: Style = .text
    var symbol: String? = nil
    let action: () -> Void

    var body: some View {
        Group {
            if style == .primary {
                PrimaryButton(title: L.t(key), symbol: symbol ?? "checkmark", action: action)
            } else {
                Button(action: action) {
                    HStack(spacing: 5) {
                        if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
                        Text(L.t(key)).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Paper.emphasis)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, style == .text ? 8 : 12)
                    .padding(.vertical, 6)
                    .frame(minWidth: 44)
                    .frame(maxWidth: style == .text ? nil : .infinity)
                    .frame(minHeight: style == .text ? 44 : 48)
                    .background(style == .outline ? Paper.tint : .clear,
                                in: RoundedRectangle(cornerRadius: 14))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PaperPressStyle())
            }
        }
        .accessibilityIdentifier(id)
    }
}

struct BudgetTile: View {
    let budget: Budget
    let isSelected: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .title) private var numberSize: CGFloat = 31

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Image(systemName: budget.tileSymbol)
                    Spacer(minLength: 0)
                    if isSelected { Image(systemName: "checkmark.circle.fill") }
                }
                .font(.subheadline.weight(.semibold))
                Text(budget.rawValue, format: .number)
                    .font(.system(size: numberSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(L.t("unit.min")).font(.caption.weight(.semibold))
            }
            .foregroundStyle(Paper.ink)
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(budget.tileColor, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18).strokeBorder(Paper.ink, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityLabel(L.f("unit.minutes", budget.rawValue))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("budget.\(budget.rawValue)")
    }
}

enum ActivityAppearance: String, CaseIterable {
    case nature, movement, drink, music, reading, creative, food, general

    var title: String { L.t("activity.category.\(rawValue)") }

    private static let starterCategories: [Self] = [
        .nature, .movement, .drink, .music, .reading, .movement, .nature, .creative, .food
    ]

    var symbol: String {
        switch self {
        case .nature: "leaf"
        case .movement: "figure.walk"
        case .drink: "cup.and.saucer"
        case .music: "music.note"
        case .reading: "book"
        case .creative: "pencil.and.outline"
        case .food: "fork.knife"
        case .general: "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .nature, .movement: Paper.mint
        case .drink, .food: Paper.yellow
        case .music, .reading, .creative: Paper.blue
        case .general: Paper.tint
        }
    }

    private var keywords: [String] {
        switch self {
        case .nature: ["nature", "plant", "plants", "garden", "window", "自然", "植物", "窗外", "花园", "花園"]
        case .movement: ["walk", "stretch", "yoga", "exercise", "movement", "散步", "伸展", "拉伸", "瑜伽", "运动", "運動"]
        case .drink: ["tea", "coffee", "drink", "茶", "咖啡", "饮品", "飲品"]
        case .music: ["music", "song", "listen", "音乐", "音樂", "听歌", "聽歌"]
        case .reading: ["read", "book", "阅读", "閱讀", "看书", "看書", "读书", "讀書"]
        case .creative: ["sketch", "paint", "draw", "craft", "paper", "creative", "画", "畫", "手工", "折纸", "摺紙", "创作", "創作"]
        case .food: ["snack", "cook", "food", "meal", "小食", "点心", "點心", "做饭", "做飯", "烹饪", "烹飪"]
        case .general: []
        }
    }

    static func forName(_ name: String, group: String = "") -> Self {
        if let explicit = matching(group) { return explicit }
        if let index = starterCategories.indices.first(where: { name == L.t("idea.\($0 + 1)") }) {
            return starterCategories[index]
        }
        return matching(name) ?? .general
    }

    private static func matching(_ text: String) -> Self? {
        guard !text.isEmpty else { return nil }
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter })
        return allCases.first { category in
            category.keywords.contains { key in
                key.utf8.allSatisfy { $0 < 128 } ? words.contains(Substring(key)) : text.contains(key)
            }
        }
    }
}

struct ActivityCard: View {
    let activity: Activity
    let id: String
    var start = true
    let action: () -> Void

    var body: some View {
        let appearance = ActivityAppearance.forName(activity.name, group: activity.group)
        Button(action: action) {
            IconRow(symbol: appearance.symbol, color: appearance.color) {
                Text(activity.name)
            } detail: {
                if !activity.group.isEmpty {
                    Text(activity.group)
                } else {
                    Text(appearance.title)
                }
            } trailing: {
                StatusPill(text: L.f("unit.minutes", activity.minutes), color: appearance.color.opacity(0.40))
                Image(systemName: start ? "play.fill" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Paper.emphasis)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(PaperPressStyle())
        .foregroundStyle(Paper.ink)
        .accessibilityLabel(L.f(start ? "activity.start.accessibility" : "activity.edit.accessibility",
                                activity.name, activity.minutes))
        .accessibilityIdentifier(id)
    }
}

struct BottomActions<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 8) {
            content
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, 21)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Paper.background)
    }
}

struct PageLayout<Header: View, Content: View, Footer: View>: View {
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                content
                footer
            }
            .frame(maxWidth: 480, alignment: .leading)
            .padding(.horizontal, 21)
            .padding(.top, 8)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(Paper.ink)
        .background(Paper.background.ignoresSafeArea())
    }
}
