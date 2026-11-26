import SwiftUI
import StoreKit

@main
struct DopamineMenuApp: App {
    var body: some Scene {
        WindowGroup {
            MenuRoot()
        }
    }
}

@MainActor
struct MenuRoot: View {
    enum Page: Equatable {
        case home, session, done, menu, editor, history, importMenu, share, paywall, widgets
    }

    @StateObject private var model = AppModel()
    @StateObject private var purchases = Purchases()
    @Environment(\.scenePhase) private var phase
    @Environment(\.requestReview) private var requestReview

    @State private var page = Page.home
    @State private var paywallBack = Page.home
    @State private var editorBack = Page.menu
    @State private var historyBack = Page.home
    @State private var shareBack = Page.menu
    @State private var draft = Activity(name: "", minutes: 5)
    @State private var latest: Completion?
    @State private var shareMilestone = false
    @State private var showingGroups = false
    @State private var reviewOpportunity: UUID?
    @State private var reviewAttempted = false
    @State private var initialized = false
    @State private var openedFromWidget = false
    @State private var wasBackgrounded = false

    var body: some View {
        Group {
            if model.ready {
                pages
            } else if model.loadFailed {
                EmptyState(symbol: "exclamationmark.triangle") {
                    Text(L.t("storage.load"))
                    PaperButton(key: "common.retry", id: "storage.retry", style: .primary,
                                symbol: "arrow.clockwise") {
                        Task { await start() }
                    }
                }
                .frame(maxWidth: 480)
                .padding(24)
            } else {
                ProgressView(L.t("common.loading"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paper.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if model.storageError {
                HStack {
                    Text(L.t("storage.write")).font(.footnote)
                    Spacer()
                    PaperButton(key: "common.retry", id: "storage.resave", action: model.persist)
                }
                .padding(.horizontal, 20)
                .background(Paper.tint)
            }
        }
        .tint(Paper.emphasis)
        .preferredColorScheme(.light)
        .task { await start() }
        .task(id: model.ready) {
            guard model.ready else { return }
            await purchases.listen(model: model)
        }
        .task(id: model.entitlement) { await model.watchExpiry() }
        .task(id: reviewOpportunity) {
            guard let opportunity = reviewOpportunity, canReview else { return }
            do { try await Task.sleep(for: .milliseconds(1100)) } catch { return }
            guard reviewOpportunity == opportunity, canReview else { return }
            reviewOpportunity = nil
            model.markReviewAttempt()
            if Launch.uiTesting { reviewAttempted = true } else { requestReview() }
        }
        .onChange(of: canReview) { _, idle in
            if !idle { reviewOpportunity = nil }
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase != .active { reviewOpportunity = nil }
            if newPhase == .background {
                wasBackgrounded = true
                model.checkpoint()
            } else if newPhase == .active, model.ready {
                if wasBackgrounded && !openedFromWidget && page == .home && model.data.active != nil {
                    page = .session
                }
                wasBackgrounded = false
                openedFromWidget = false
                model.checkExpiry()
                Task { await purchases.refresh(model: model) }
            }
        }
        .onOpenURL { url in
            if model.open(url) {
                reviewOpportunity = nil
                showingGroups = false
                openedFromWidget = !initialized || phase != .active
                page = .home
            }
        }
    }

    private var canReview: Bool {
        phase == .active && page == .home && model.ready && model.data.active == nil &&
        !showingGroups && !purchases.busy && purchases.error == nil &&
        model.notice == nil && !model.storageError && !model.candidates.isEmpty && model.shouldRequestReview
    }

    private func start() async {
        await model.load()
        guard model.ready, !initialized else { return }
        initialized = true
        if Launch.testFlag("-paywall") {
            page = .paywall
        } else if Launch.testFlag("-widget-guide") {
            page = .widgets
        } else if model.data.active != nil && !openedFromWidget {
            page = .session
        }
        await purchases.refresh(model: model)
    }

    @ViewBuilder private var pages: some View {
        switch page {
        case .home:
            HomeScreen(model: model, showingGroups: $showingGroups, reviewAttempted: reviewAttempted,
                       openMenu: { page = .menu }, addActivity: { openEditor(nil, from: .home) },
                       editActivity: { openEditor($0, from: .home) }, openImport: { page = .importMenu },
                       openShare: { showShare(milestone: false) }, openHistory: showHistory,
                       openPaywall: showPaywall, openWidgets: { page = .widgets },
                       openActivity: {
                           if let activity = $0 { model.start(activity) }
                           if model.data.active != nil { page = .session }
                       })
        case .session:
            if let session = model.data.active {
                SessionScreen(model: model, session: session, back: { page = .home },
                              finish: {
                                  if let completion = model.complete() {
                                      latest = completion
                                      page = .done
                                  }
                              }, end: { model.end(); page = .home })
            }
        case .done:
            if let latest {
                DoneScreen(completion: latest, milestone: model.data.history.count == 7,
                           back: { returnAfterCompletion(latest.id) }, undo: {
                               if model.undo(latest.id) {
                                   self.latest = nil
                                   reviewOpportunity = nil
                                   page = .home
                               }
                           }, share: { showShare(milestone: true) })
            }
        case .menu:
            PersonalMenu(model: model, back: { page = .home }, history: showHistory,
                         edit: { openEditor($0, from: .menu) }, share: { showShare(milestone: false) })
        case .editor:
            ActivityEditor(activity: $draft, hasPro: model.hasPro,
                           saved: model.data.activities.contains { $0.id == draft.id },
                           cancel: { page = editorBack }, save: {
                               model.save(draft)
                               page = editorBack
                           }, archive: {
                               model.setArchived(draft.id, archived: !draft.archived)
                               page = editorBack
                           })
        case .history:
            HistoryScreen(model: model, back: { page = historyBack }, share: { showShare(milestone: true) })
        case .importMenu:
            ImportScreen(model: model, back: { page = .home })
        case .share:
            ShareScreen(activities: model.data.activities, milestone: shareMilestone,
                        hasPro: model.hasPro, back: { page = shareBack })
        case .widgets:
            WidgetGuide(back: { page = .home }, choose: { budget in
                if let budget { model.select(budget) }
                page = .home
            })
        case .paywall:
            Paywall(model: model, purchases: purchases, back: {
                purchases.error = nil
                page = paywallBack
            })
        }
    }

    private func openEditor(_ activity: Activity?, from: Page) {
        draft = activity ?? Activity(name: "", minutes: 5)
        editorBack = from
        page = .editor
    }

    private func returnAfterCompletion(_ id: UUID) {
        latest = nil
        page = .home
        if canReview { reviewOpportunity = id }
    }

    private func showHistory() {
        historyBack = page
        page = .history
    }

    private func showShare(milestone: Bool) {
        shareBack = page
        shareMilestone = milestone
        page = .share
    }

    private func showPaywall() {
        paywallBack = page
        purchases.error = nil
        page = .paywall
    }
}
