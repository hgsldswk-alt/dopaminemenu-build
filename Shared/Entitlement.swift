import Foundation

struct Entitlement: Codable, Equatable {
    static let trialDuration: TimeInterval = 30 * 86_400
    var firstOpen: Date = .now
    var proStartedAt: Date?
    var purchasedPro = false
    var trialClaimedAt: Date?
    var trialRevoked = false

    var trialStart: Date { proStartedAt ?? firstOpen }
    var trialEnd: Date { trialStart.addingTimeInterval(Self.trialDuration) }

    func hasPro(at now: Date, free: Bool = Launch.freePeriod) -> Bool {
        free || purchasedPro || (!trialRevoked && now >= trialStart && now < trialEnd)
    }

    mutating func applyTrial(originalDate: Date, revoked: Bool) {
        trialClaimedAt = originalDate
        trialRevoked = revoked
        proStartedAt = min(trialStart, originalDate)
    }
}
