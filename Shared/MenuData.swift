import Foundation

struct Activity: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var minutes: Int
    var lowEnergy = false
    var shareable = false
    var hint = ""
    var group = ""
    var archived = false
}

enum StarterIdeas {
    static var activities: [Activity] {
        let minutes = [1, 2, 5, 4, 10, 15, 20, 25, 30]
        return minutes.enumerated().map { index, duration in
            let id = UUID(uuidString: "00000000-0000-4000-8000-00000000000\(index + 1)")!
            return Activity(id: id, name: L.t("idea.\(index + 1)"), minutes: duration,
                            lowEnergy: index != 5 && index != 6 && index != 8, shareable: true)
        }
    }
}

enum MenuPicker {
    static func options(from activities: [Activity], budget: Budget, lowEnergy: Bool, group: String) -> [Activity] {
        activities.filter {
            !$0.archived && (1...budget.rawValue).contains($0.minutes) &&
            (!lowEnergy || $0.lowEnergy) && (group.isEmpty || $0.group == group)
        }
    }

    static func draw(from pool: [Activity], budget: Budget, recent: [UUID]) -> [Activity] {
        var ranked = pool.shuffled().sorted {
            rank($0.id, recent: recent) > rank($1.id, recent: recent)
        }
        var picks: [Activity] = []
        let previous = Set(recent.prefix(3))
        if budget != .five, let featured = ranked.firstIndex(where: { $0.minutes >= budget.lowerBand }) {
            picks.append(ranked.remove(at: featured))
        }
        picks.append(contentsOf: ranked.prefix(3 - picks.count))
        if Set(picks.map(\.id)) == previous, let next = ranked.first(where: { !previous.contains($0.id) }),
           let replace = picks.lastIndex(where: { pick in
               budget == .five || pick.minutes < budget.lowerBand ||
               next.minutes >= budget.lowerBand || picks.filter { $0.minutes >= budget.lowerBand }.count > 1
           }) {
            picks[replace] = next
        }
        return picks
    }

    private static func rank(_ id: UUID, recent: [UUID]) -> Int {
        recent.firstIndex(of: id) ?? recent.count
    }
}

struct Session: Codable, Equatable, Identifiable {
    var id = UUID()
    var activity: Activity
    var showsTimer: Bool
    var checkpoint: Date
    var secondsAtCheckpoint: TimeInterval

    init(activity: Activity, showsTimer: Bool, now: Date) {
        self.activity = activity
        self.showsTimer = showsTimer
        checkpoint = now
        secondsAtCheckpoint = TimeInterval(activity.minutes * 60)
    }

    func remaining(after elapsed: TimeInterval) -> TimeInterval {
        max(0, min(TimeInterval(activity.minutes * 60), secondsAtCheckpoint - max(0, elapsed)))
    }

    func restored(at now: Date) -> TimeInterval {
        remaining(after: now.timeIntervalSince(checkpoint))
    }
}

struct Completion: Codable, Equatable, Identifiable {
    var id: UUID
    var activity: Activity
    var date: Date
    var day: String

    init(session: Session, now: Date, calendar: Calendar) {
        id = session.id
        activity = session.activity
        date = now
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        day = "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}

struct MenuData: Codable, Equatable {
    var activities: [Activity] = []
    var history: [Completion] = []
    var active: Session?
    var budget: Budget = .five
    var showsTimer = true
    var haptics = false
    var candidateIDs: [UUID] = []
    var recentIDs: [UUID] = []
    var sampleMode = false
    var lowEnergy = false
    var group = ""
    var reviewVersion: String?
    var reviewPending = false
    var lastCompletion: UUID?

    var distinctDays: Int { Set(history.map(\.day)).count }
    var reachedMilestone: Bool { history.count >= 7 }

    mutating func complete(at now: Date, calendar: Calendar = .current) -> Completion? {
        guard let active, !history.contains(where: { $0.id == active.id }) else { return nil }
        let item = Completion(session: active, now: now, calendar: calendar)
        history.insert(item, at: 0)
        self.active = nil
        lastCompletion = item.id
        reviewPending = distinctDays >= 3
        return item
    }

    mutating func undo(_ id: UUID) -> Bool {
        guard lastCompletion == id, history.first?.id == id else { return false }
        history.removeFirst()
        lastCompletion = nil
        reviewPending = false
        return true
    }
}
