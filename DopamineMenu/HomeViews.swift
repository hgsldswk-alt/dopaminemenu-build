import SwiftUI
import UIKit

@MainActor
struct HomeScreen: View {
    @ObservedObject var model: AppModel
    @Binding var showingGroups: Bool
    let reviewAttempted: Bool
    let openMenu: () -> Void
    let addActivity: () -> Void
    let editActivity: (Activity) -> Void
    let openImport: () -> Void
    let openShare: () -> Void
    let openHistory: () -> Void
    let openPaywall: () -> Void
    let openWidgets: () -> Void
    let openActivity: (Activity?) -> Void

    var body: some View {
        PageLayout {
            ViewThatFits(in: .horizontal) {
                HStack {
                    wordmark
                    Spacer(minLength: 0)
                    quickActions
                }
                VStack(alignment: .leading, spacing: 4) {
                    wordmark
                    quickActions
                }
            }
        } content: {
            VStack(spacing: 12) {
                HeroCard(symbol: "timer") {
                    Paper.heading(L.t("home.question"))
                    Text(L.f("unit.minutes", model.data.budget.rawValue))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(Paper.emphasis)
                        .accessibilityHidden(true)
                }
                HStack(spacing: 8) {
                    ForEach(Budget.allCases) { budget in
                        BudgetTile(budget: budget, isSelected: budget == model.data.budget) { model.select(budget) }
                    }
                }
            }
            if let active = model.data.active {
                PaperButton(key: "home.resume", id: "home.resume", style: .outline, symbol: "play.fill") { openActivity(nil) }
                    .accessibilityValue(active.activity.name)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L.t(model.usingIdeas ? "home.starters" : "menu.title")).sectionHeading()
                    Spacer(minLength: 0)
                    PaperButton(key: "home.shuffle", id: "home.shuffle", symbol: "shuffle", action: model.shuffle)
                        .disabled(model.pool.isEmpty)
                }
                if model.hasPro { filters }
                ForEach(Array(model.candidates.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 6) {
                        ActivityCard(activity: item, id: "home.activity.\(index)") { openActivity(item) }
                        if !model.usingIdeas {
                            Button { editActivity(item) } label: {
                                SymbolBadge(symbol: "pencil", color: Paper.tint, size: 34)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PaperPressStyle())
                            .accessibilityLabel(L.f("home.editActivity", item.name))
                            .accessibilityIdentifier("home.edit.\(index)")
                        }
                    }
                }
                if model.candidates.isEmpty {
                    EmptyState(symbol: "tray") {
                        Text(L.t(model.filtersActive ? "home.noFiltered" : "home.noMatch"))
                            .accessibilityIdentifier("home.empty")
                        if !model.usingIdeas {
                            PaperButton(key: "home.useIdeas", id: "home.useIdeas", style: .primary,
                                        symbol: "sparkles", action: model.useSamples)
                        } else {
                            PrimaryButton(title: L.t("editor.add"), symbol: "plus", action: addActivity)
                        }
                    }
                }
                if let notice = model.notice {
                    Text(L.t(notice)).font(.footnote).foregroundStyle(Paper.secondary)
                        .accessibilityIdentifier("home.shuffleNotice")
                }
            }
            if model.usingIdeas && !model.data.activities.isEmpty {
                PaperButton(key: "home.usePersonal", id: "home.usePersonal", style: .outline,
                            symbol: "list.bullet", action: model.usePersonal)
            }
        } footer: {
            VStack(spacing: 8) {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        IconTile(key: "menu.title", id: "home.menu", symbol: "list.bullet",
                                 color: Paper.mint, action: openMenu)
                        IconTile(key: "history.title", id: "home.history", symbol: "clock.arrow.circlepath",
                                 color: Paper.blue, action: openHistory)
                    }
                    GridRow {
                        IconTile(key: "share.menu", id: "home.share", symbol: "square.and.arrow.up",
                                 color: Paper.yellow, action: openShare)
                        IconTile(key: "import.action", id: "home.import", symbol: "square.and.arrow.down",
                                 color: Paper.tint, action: openImport)
                    }
                }
                PaperButton(key: model.entitlement.purchasedPro ? "pro.manage" :
                            model.hasPro && model.entitlement.trialClaimedAt == nil ? "pro.trialEntry" : "pro.entry",
                            id: "home.pro", symbol: "star", action: openPaywall)
                if reviewAttempted {
                    Text(L.t("review.requested")).accessibilityIdentifier("review.requested")
                }
            }
        }
    }

    private var wordmark: some View {
        Text(L.t("app.name")).font(.subheadline.bold()).foregroundStyle(Paper.emphasis)
    }

    private var quickActions: some View {
        HStack(spacing: 2) {
            PaperButton(key: "home.add", id: "home.add", style: .outline, action: addActivity)
            PaperButton(key: "home.widgets", id: "home.widgets", symbol: "square.grid.2x2", action: openWidgets)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var filters: some View {
        let lowEnergy = model.data.lowEnergy
        return HStack {
            Button {
                model.filter(lowEnergy: !lowEnergy)
            } label: {
                HStack(spacing: 6) {
                    SymbolBadge(symbol: "leaf", color: Paper.mint, size: 24, circular: true)
                    Text(L.t("filter.low"))
                        .fixedSize(horizontal: false, vertical: true)
                    if lowEnergy {
                        Image(systemName: "checkmark").accessibilityHidden(true)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Paper.ink)
                .padding(.leading, 6)
                .padding(.trailing, 12)
                .padding(.vertical, 6)
                .frame(minHeight: 44)
                .background(lowEnergy ? Paper.mint.opacity(0.30) : Paper.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(lowEnergy ? Paper.ink : Paper.line) }
                .contentShape(Capsule())
            }
            .buttonStyle(PaperPressStyle())
            .accessibilityAddTraits(lowEnergy ? .isSelected : [])
            .accessibilityIdentifier("filter.low")
            Spacer(minLength: 0)
            if !model.usingIdeas && !model.availableGroups.isEmpty {
                Button { showingGroups = true } label: {
                    Label(model.data.group.isEmpty ? L.t("filter.groups") : model.data.group,
                          systemImage: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Paper.emphasis)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(Paper.tint, in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("filter.groups")
                .popover(isPresented: $showingGroups) {
                    ScrollView {
                        VStack(alignment: .leading) {
                            PaperButton(key: "filter.all", id: "filter.all") { selectGroup("") }
                            ForEach(model.availableGroups, id: \.self) { group in
                                Button(group) { selectGroup(group) }
                                    .frame(minHeight: 44)
                                    .accessibilityAddTraits(model.data.group == group ? .isSelected : [])
                                    .accessibilityIdentifier("filter.group.\(group)")
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(idealWidth: 220, maxHeight: 300)
                    .presentationCompactAdaptation(.popover)
                }
            }
        }
    }

    private func selectGroup(_ group: String) {
        model.filter(group: group)
        showingGroups = false
    }
}

@MainActor
struct SessionScreen: View {
    @ObservedObject var model: AppModel
    let session: Session
    let back: () -> Void
    let finish: () -> Void
    let end: () -> Void
    @Environment(\.scenePhase) private var phase
    @State private var signalled = false

    var body: some View {
        PageLayout {
            PaperButton(key: "common.menu", id: "session.back", action: back)
        } content: {
            HeroCard(symbol: ActivityAppearance.forName(session.activity.name, group: session.activity.group).symbol) {
                Text(L.t("session.title")).font(.subheadline.bold()).foregroundStyle(Paper.emphasis)
                Paper.heading(session.activity.name).accessibilityIdentifier("session.activity")
                if !session.activity.hint.isEmpty { Text(session.activity.hint).foregroundStyle(Paper.secondary) }
            }
            if session.showsTimer {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    let remaining = model.remaining()
                    let seconds = Int(ceil(remaining))
                    let fraction = remaining / max(1, Double(session.activity.minutes * 60))
                    VStack(spacing: 12) {
                        Circle()
                            .stroke(Paper.mint.opacity(0.23), lineWidth: 12)
                            .overlay {
                                Circle()
                                    .trim(from: 0, to: CGFloat(fraction))
                                    .stroke(Paper.mint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .accessibilityHidden(true)
                            }
                            .overlay {
                                Text(L.f("timer.clock", seconds / 60, seconds % 60))
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .monospacedDigit().minimumScaleFactor(0.45).lineLimit(1)
                                    .foregroundStyle(Paper.ink)
                                    .padding(24)
                                    .accessibilityLabel(L.f("timer.accessibility", seconds / 60, seconds % 60))
                                    .accessibilityIdentifier("session.timer")
                            }
                            .frame(maxWidth: 208)
                        Text(seconds == 0 ? L.t("session.timeUp") : L.t("session.remaining"))
                            .font(.headline).foregroundStyle(Paper.secondary).multilineTextAlignment(.center)
                            .accessibilityIdentifier(seconds == 0 ? "session.timeUp" : "session.remaining")
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .paperCard()
                    .onChange(of: seconds == 0) { _, finished in
                        if finished && !signalled && phase == .active && model.data.haptics {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            signalled = true
                        }
                    }
                }
                PaperButton(key: "session.hide", id: "session.hide", style: .outline,
                            symbol: "eye.slash", action: model.hideTimer)
            } else {
                StatusPill(text: L.t("session.untimed"), color: Paper.blue.opacity(0.36))
                    .accessibilityIdentifier("session.untimed")
            }
        } footer: {
            VStack(spacing: 8) {
                PaperButton(key: "session.done", id: "session.done", style: .primary, action: finish)
                PaperButton(key: "session.end", id: "session.end", style: .outline, symbol: "stop", action: end)
            }
        }
    }
}

struct DoneScreen: View {
    let completion: Completion
    let milestone: Bool
    let back: () -> Void
    let undo: () -> Void
    let share: () -> Void

    var body: some View {
        PageLayout {
            HStack {
                Text(L.t("app.name")).font(.subheadline.bold()).foregroundStyle(Paper.emphasis)
                Spacer()
                PaperButton(key: "done.undo", id: "done.undo", symbol: "arrow.uturn.backward", action: undo)
            }
        } content: {
            HeroCard(symbol: "checkmark.circle.fill") {
                Paper.heading(L.t("done.title")).accessibilityIdentifier("done.title")
                Text(L.f("done.saved", completion.activity.name)).foregroundStyle(Paper.secondary)
            }
            if milestone {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L.t("milestone.title")).sectionHeading()
                        .accessibilityIdentifier("done.milestoneTitle")
                    PaperButton(key: "milestone.open", id: "done.milestone", style: .outline, symbol: "sparkles", action: share)
                }
                .padding(14)
                .paperCard()
            }
        } footer: {
            PaperButton(key: "done.back", id: "done.back", style: .primary, symbol: "list.bullet", action: back)
        }
    }
}
