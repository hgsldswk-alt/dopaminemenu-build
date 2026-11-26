import Combine
import Foundation
import StoreKit
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var data = MenuData()
    @Published private(set) var entitlement = Entitlement(firstOpen: .distantPast)
    @Published private(set) var ready = false
    @Published private(set) var loadFailed = false
    @Published private(set) var storageError = false
    @Published private(set) var notice: String?
    @Published private(set) var hasPro = false

    private let store = LocalStore()
    private let clock = ContinuousClock()
    private var timerAnchor: ContinuousClock.Instant?
    private var timerBase: TimeInterval = 0
    private var pendingRoute: WidgetRoute?
    private var savingRevision = 0
    private var widgetBudget: Budget?

    var activeIsTimed: Bool { data.active?.showsTimer == true }
    var availableGroups: [String] {
        Set(data.activities.filter { !$0.archived }.map(\.group).filter { !$0.isEmpty }).sorted()
    }
    var usingIdeas: Bool { data.activities.isEmpty || data.sampleMode }
    var filtersActive: Bool { hasPro && (data.lowEnergy || (!usingIdeas && !data.group.isEmpty)) }
    var pool: [Activity] {
        MenuPicker.options(from: usingIdeas ? StarterIdeas.activities : data.activities,
                           budget: data.budget, lowEnergy: hasPro && data.lowEnergy,
                           group: hasPro && !usingIdeas ? data.group : "")
    }
    var candidates: [Activity] {
        let options = pool
        return data.candidateIDs.compactMap { id in options.first { $0.id == id } }
    }

    func load() async {
        guard !ready else { return }
        loadFailed = false
        do {
            (data, entitlement) = try await store.load(reset: Launch.testFlag("-reset"))
            if Launch.testFlag("-expired") {
                entitlement = Entitlement(firstOpen: Date.now.addingTimeInterval(-31 * 86_400))
            }
            if Launch.testFlag("-entitlement-unavailable") {
                entitlement = Entitlement(trialRevoked: true)
            }
            let seedCount = Launch.testFlag("-seed-history") ? 6 : Launch.testFlag("-seed-review-days") ? 2 : 0
            if seedCount > 0, data.history.isEmpty {
                for index in (1...seedCount).reversed() {
                    let now = Calendar.current.date(byAdding: .day, value: -index, to: .now) ?? .now
                    let sample = StarterIdeas.activities[index % StarterIdeas.activities.count]
                    data.active = Session(activity: sample, showsTimer: false, now: now)
                    _ = data.complete(at: now)
                }
            }
            data.reviewPending = false
            if let active = data.active {
                setTimer(active.restored(at: .now))
            }
            hasPro = entitlement.hasPro(at: .now)
            ready = true
            if Launch.testFlag("-widget-15") { pendingRoute = .timed(.fifteen) }
            applyPendingRoute()
            if data.candidateIDs.count != min(pool.count, 3) || candidates.count != data.candidateIDs.count {
                refresh(initial: true)
            }
            persist()
        } catch {
            loadFailed = true
        }
    }

    func persist() {
        guard ready else { return }
        savingRevision += 1
        let revision = savingRevision
        let budget = data.budget
        store.save(data, publishWidget: widgetBudget != budget || storageError) { result in
            Task { @MainActor in
                if result.published {
                    self.widgetBudget = budget
                    WidgetCenter.shared.reloadAllTimelines()
                }
                if self.savingRevision == revision { self.storageError = !result.saved }
            }
        }
    }

    func open(_ url: URL) -> Bool {
        guard let route = WidgetRoute(url: url) else { return false }
        pendingRoute = route
        if ready { applyPendingRoute() }
        return true
    }

    private func applyPendingRoute() {
        guard let route = pendingRoute else { return }
        pendingRoute = nil
        if case .timed(let budget) = route { select(budget) }
    }

    func select(_ budget: Budget) {
        guard budget != data.budget else { return }
        data.budget = budget
        refresh()
        persist()
    }

    func shuffle() {
        let previous = Set(data.candidateIDs)
        refresh()
        if Set(data.candidateIDs) == previous {
            notice = pool.count > 3 ? "home.unchanged" : "home.short"
        }
        persist()
    }

    func useSamples() {
        data.sampleMode = true
        refresh()
        persist()
    }

    func usePersonal() {
        data.sampleMode = false
        refresh()
        persist()
    }

    func filter(lowEnergy: Bool? = nil, group: String? = nil) {
        guard hasPro else { return }
        if let lowEnergy { data.lowEnergy = lowEnergy }
        if let group { data.group = group }
        refresh()
        persist()
    }

    func save(_ activity: Activity) {
        if let index = data.activities.firstIndex(where: { $0.id == activity.id }) {
            data.activities[index] = activity
        } else {
            data.activities.append(activity)
        }
        data.sampleMode = false
        if hasPro && !availableGroups.contains(data.group) { data.group = "" }
        refresh()
        persist()
    }

    func setArchived(_ id: UUID, archived: Bool) {
        guard var activity = data.activities.first(where: { $0.id == id }),
              activity.archived != archived else { return }
        activity.archived = archived
        save(activity)
    }

    func merge(_ items: [MenuCode.Item]) {
        let fresh = MenuCode.merge(items, existing: data.activities).newItems
        guard !fresh.isEmpty else { return }
        data.activities.append(contentsOf: fresh.map(\.activity))
        data.sampleMode = false
        refresh()
        persist()
    }

    private func refresh(initial: Bool = false) {
        notice = nil
        let choices = pool
        let featured = initial && data.activities.isEmpty && data.budget == .five && data.recentIDs.isEmpty
            ? Array(choices.prefix(3))
            : MenuPicker.draw(from: choices, budget: data.budget, recent: data.recentIDs)
        data.candidateIDs = featured.map(\.id)
        let old = data.recentIDs.filter { !data.candidateIDs.contains($0) }
        data.recentIDs = Array((data.candidateIDs + old).prefix(64))
    }

    func start(_ activity: Activity) {
        guard data.active == nil else { return }
        var session = Session(activity: activity, showsTimer: data.showsTimer, now: .now)
        if Launch.testFlag("-timer-zero") { session.secondsAtCheckpoint = 0 }
        data.active = session
        setTimer(session.secondsAtCheckpoint)
        persist()
    }

    func remaining() -> TimeInterval {
        guard let timerAnchor else { return 0 }
        let duration = timerAnchor.duration(to: clock.now).components
        return max(0, timerBase - Double(duration.seconds) - Double(duration.attoseconds) / 1e18)
    }

    func checkpoint() {
        guard activeIsTimed else { return }
        let seconds = remaining()
        data.active?.secondsAtCheckpoint = seconds
        data.active?.checkpoint = .now
        persist()
    }

    private func setTimer(_ remaining: TimeInterval) {
        timerBase = remaining
        timerAnchor = clock.now
    }

    func hideTimer() {
        guard data.active != nil else { return }
        data.active?.showsTimer = false
        data.showsTimer = false
        persist()
    }

    func setTimerPreference(_ on: Bool) {
        data.showsTimer = on
        persist()
    }

    func setHaptics(_ on: Bool) {
        data.haptics = on
        persist()
    }

    func end() {
        data.active = nil
        timerAnchor = nil
        persist()
    }

    func complete() -> Completion? {
        guard let completion = data.complete(at: .now) else { return nil }
        timerAnchor = nil
        persist()
        return completion
    }

    func undo(_ id: UUID) -> Bool {
        guard data.undo(id) else { return false }
        persist()
        return true
    }

    var shouldRequestReview: Bool {
        data.reviewPending && data.distinctDays >= 3 && data.reviewVersion != currentVersion
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    func markReviewAttempt() {
        data.reviewVersion = currentVersion
        data.reviewPending = false
        persist()
    }

    func updateEntitlement(_ updated: Entitlement) {
        guard entitlement != updated else { return }
        entitlement = updated
        store.save(updated)
        checkExpiry()
    }

    func checkExpiry() {
        let available = entitlement.hasPro(at: .now)
        guard hasPro != available else { return }
        let wasFiltering = filtersActive
        hasPro = available
        if wasFiltering || filtersActive {
            refresh()
            persist()
        }
    }

    func watchExpiry() async {
        let seconds = entitlement.trialEnd.timeIntervalSinceNow
        guard !entitlement.purchasedPro, seconds > 0 else { return }
        do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
        checkExpiry()
    }
}
