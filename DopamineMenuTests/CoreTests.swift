import CoreImage
import XCTest

final class CoreTests: XCTestCase {
    func testBudgetEdgesAndFilters() {
        let rows = [1, 5, 6, 15, 16, 30, 31].map {
            Activity(name: "\($0)", minutes: $0, lowEnergy: $0 == 5, group: "Home")
        }
        let cases: [(Budget, [Int])] = [(.five, [1, 5]), (.fifteen, [1, 5, 6, 15]),
                                                   (.thirty, [1, 5, 6, 15, 16, 30])]
        for (budget, expected) in cases {
            let pool = MenuPicker.options(from: rows, budget: budget, lowEnergy: false, group: "")
            XCTAssertEqual(pool.map(\.minutes), expected)
            let cards = MenuPicker.draw(from: pool, budget: budget, recent: [])
            XCTAssertEqual(cards.count, min(3, expected.count))
            XCTAssertEqual(Set(cards.map(\.id)).count, cards.count)
            XCTAssertTrue(cards.contains { $0.minutes >= budget.lowerBand })
        }
        var archived = rows[1]
        archived.archived = true
        XCTAssertTrue(MenuPicker.options(from: [archived], budget: .five, lowEnergy: false, group: "").isEmpty)
        XCTAssertEqual(MenuPicker.options(from: rows, budget: .five, lowEnergy: true, group: "Home").map(\.minutes), [5])
        XCTAssertTrue(MenuPicker.options(from: rows, budget: .five, lowEnergy: true, group: "Outside").isEmpty)
    }

    func testRerollAvoidsPreviousBatchAndKeepsLongPick() {
        let rows = [5, 9, 10, 30].map { Activity(name: "\($0)", minutes: $0) }
        let first = Array(rows.dropFirst())
        for _ in 0..<30 {
            let draws = MenuPicker.draw(from: rows, budget: .thirty, recent: first.map(\.id))
            XCTAssertTrue(draws.contains(rows[3]))
            XCTAssertNotEqual(Set(draws.map(\.id)), Set(first.map(\.id)))
        }
        XCTAssertTrue(MenuPicker.draw(from: [], budget: .five, recent: []).isEmpty)
    }

    func testSessionCheckpointAndClockChanges() throws {
        let start = Date(timeIntervalSince1970: 86_380)
        let activity = Activity(name: "Read", minutes: 5)
        let active = Session(activity: activity, showsTimer: true, now: start)
        XCTAssertEqual(active.restored(at: start.addingTimeInterval(65)), 235)
        XCTAssertEqual(active.restored(at: start.addingTimeInterval(-60)), 300)
        XCTAssertEqual(active.restored(at: start.addingTimeInterval(1000)), 0)
        XCTAssertEqual(active.remaining(after: 42), 258)
        var data = MenuData()
        data.active = active
        data.activities = [Activity(id: activity.id, name: "Renamed", minutes: 10, archived: true)]
        let saved = try JSONDecoder().decode(MenuData.self, from: JSONEncoder().encode(data))
        XCTAssertEqual(saved, data)
        XCTAssertEqual(saved.active?.activity, activity)
    }

    func testCompleteOnceAcrossMidnightAndUndoMilestone() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let start = Date(timeIntervalSince1970: 86_399)
        var data = MenuData()
        let activity = Activity(name: "Read", minutes: 1)
        for day in 1...3 {
            for _ in 0..<2 {
                let now = start.addingTimeInterval(Double(day - 1) * 86_400)
                data.active = Session(activity: activity, showsTimer: false, now: now)
                let completed = try XCTUnwrap(data.complete(at: now.addingTimeInterval(5), calendar: calendar))
                if day == 1 { XCTAssertEqual(completed.day, "1970-1-2") }
                XCTAssertNil(data.complete(at: now, calendar: calendar))
            }
        }
        XCTAssertEqual(data.distinctDays, 3)
        XCTAssertTrue(data.reviewPending)
        XCTAssertFalse(data.reachedMilestone)
        data.active = Session(activity: activity, showsTimer: false, now: start)
        let seventh = try XCTUnwrap(data.complete(at: start, calendar: calendar))
        XCTAssertTrue(data.reachedMilestone)
        XCTAssertFalse(data.undo(UUID()))
        XCTAssertTrue(data.undo(seventh.id))
        XCTAssertFalse(data.undo(seventh.id))
        XCTAssertFalse(data.reachedMilestone)
        XCTAssertFalse(data.reviewPending)
    }

    func testCodePrivacyRoundTripAndMerge() throws {
        let shared = Activity(name: "Café", minutes: 5, lowEnergy: true, shareable: true, hint: "private", group: "Home")
        let card = ShareCardData(activities: [shared, Activity(name: "Secret", minutes: 5),
                                            Activity(name: "Old", minutes: 5, shareable: true, archived: true)])
        XCTAssertFalse(card.usesSamples)
        let code = try MenuCode.encode(card.items)
        let items = try MenuCode.decode(" \n" + code + "\n")
        XCTAssertEqual(items, [.init(name: "Café", minutes: 5)])
        XCTAssertEqual(items[0].activity.hint, "")
        XCTAssertEqual(items[0].activity.group, "")
        XCTAssertFalse(items[0].activity.shareable)
        let mixed = items + [.init(name: "CAFÉ", minutes: 5), .init(name: "Café", minutes: 6)]
        let merge = MenuCode.merge(mixed, existing: [.init(name: "  Cafe\u{301}  ", minutes: 5)])
        XCTAssertEqual(merge.duplicates, 2)
        XCTAssertEqual(merge.newItems, [.init(name: "Café", minutes: 6)])
        XCTAssertTrue(ShareCardData(activities: []).usesSamples)
        let long = ShareCardData(activities: (1...14).map { .init(name: "A \($0)", minutes: $0, shareable: true) })
        XCTAssertEqual(long.total, 14)
        XCTAssertEqual(long.items.count, 12)
        XCTAssertEqual(long.items.last?.minutes, 12)
    }

    func testRejectInvalidCodes() throws {
        XCTAssertThrowsError(try MenuCode.decode("DM2:abc"))
        XCTAssertThrowsError(try MenuCode.decode("DM1:"))
        XCTAssertThrowsError(try MenuCode.decode("DM1:" + String(repeating: "e", count: 3073)))
        XCTAssertThrowsError(try MenuCode.encode([.init(name: "To\ndo", minutes: 1)]))
        XCTAssertThrowsError(try MenuCode.encode([.init(name: "Test", minutes: 31)]))
        XCTAssertThrowsError(try MenuCode.encode([.init(name: String(repeating: "a", count: 49), minutes: 1)]))
        XCTAssertThrowsError(try MenuCode.encode([.init(name: String(repeating: "🙂", count: 40), minutes: 1)]))
        let extra = Data(#"[{"name":"Tea","minutes":5,"note":"private"}]"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        XCTAssertThrowsError(try MenuCode.decode("DM1:" + extra))
    }

    func testImageCaptionRoundTripsWithoutPrivateFields() throws {
        let activity = Activity(name: "Tea", minutes: 5, shareable: true, hint: "private", group: "Home")
        let card = ShareCardData(activities: [activity])
        let caption = try card.imageCaption()
        let code = try MenuCode.encode(card.items)
        XCTAssertTrue(caption.hasPrefix(L.t("share.caption") + "\n\nDM1:"))
        XCTAssertEqual(try MenuCode.decode(caption), [.init(name: "Tea", minutes: 5)])
        XCTAssertEqual(try MenuCode.decode("Share text\r\n\r\n " + code + " \r\n"), card.items)
        XCTAssertThrowsError(try MenuCode.decode(caption + "\n" + code))
        XCTAssertThrowsError(try MenuCode.decode("Share text\n" + code + "!"))
        XCTAssertThrowsError(try MenuCode.decode(String(repeating: "x", count: MenuCode.maxInputLength) + "\n" + code))
    }

    func testTrialBuyoutRevocationAndRecovery() throws {
        let start = Date(timeIntervalSince1970: 200_000)
        let deadline = start.addingTimeInterval(Entitlement.trialDuration)
        var item = Entitlement(firstOpen: start)
        XCTAssertTrue(item.hasPro(at: start, free: false))
        XCTAssertTrue(item.hasPro(at: deadline.addingTimeInterval(-1), free: false))
        XCTAssertFalse(item.hasPro(at: deadline, free: false))
        item.applyTrial(originalDate: start.addingTimeInterval(86_400), revoked: false)
        XCTAssertEqual(item.trialEnd, deadline)
        let recovered = try JSONDecoder().decode(Entitlement.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(item, recovered)
        var reinstall = Entitlement(firstOpen: deadline)
        reinstall.applyTrial(originalDate: start, revoked: false)
        XCTAssertFalse(reinstall.hasPro(at: deadline, free: false))
        item.purchasedPro = true
        XCTAssertTrue(item.hasPro(at: deadline, free: false))
        item.purchasedPro = false
        item.applyTrial(originalDate: start, revoked: true)
        XCTAssertFalse(item.hasPro(at: start, free: false))
        XCTAssertTrue(item.hasPro(at: deadline, free: true))
    }

    func testWidgetWhitelistAndPrivateSnapshot() throws {
        for budget in Budget.allCases {
            XCTAssertEqual(WidgetRoute(url: WidgetRoute.timed(budget).url), .timed(budget))
        }
        XCTAssertEqual(WidgetRoute(url: WidgetRoute.remembered.url), .remembered)
        for value in ["dopaminemenu://pick/7", "dopaminemenu://pick/5?secret=test",
                      "dopaminemenu://pick/%35", "https://pick/5"] {
            XCTAssertNil(WidgetRoute(url: try XCTUnwrap(URL(string: value))))
        }
        let snapshot = try JSONEncoder().encode(WidgetSnapshot(budget: .thirty))
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: snapshot) as? [String: Int])
        XCTAssertEqual(fields, ["version": 1, "budget": 30])
    }

    func testDownloadQRCodeReadsAtTwoSizes() throws {
        XCTAssertNil(ShareCardData.storeURL(""))
        let url = try XCTUnwrap(ShareCardData.storeURL("1234567890"))
        let qr = CIImage(cgImage: try XCTUnwrap(DownloadQR.make(for: url)))
        let detector = try XCTUnwrap(CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
                                               options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
        for scale in [1.0, 0.5] {
            let image = qr.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let features = detector.features(in: image).compactMap { $0 as? CIQRCodeFeature }
            XCTAssertEqual(features.first?.messageString, url.absoluteString)
        }
    }

    func testStarterLocalizationUsesSharedBundle() {
        XCTAssertEqual(StarterIdeas.activities.count, 9)
        XCTAssertFalse(StarterIdeas.activities[0].name.hasPrefix("idea."))
    }
}
