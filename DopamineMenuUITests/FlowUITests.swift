import XCTest

final class FlowUITests: XCTestCase {
    private enum StoreLanguage: String, CaseIterable {
        case en, hans = "zh-Hans", hant = "zh-Hant"

        var locale: String {
            switch self {
            case .en: return "en_US"
            case .hans: return "zh_CN"
            case .hant: return "zh_TW"
            }
        }
    }

    private var app: XCUIApplication!
    private var tapCount = 0
    private let uiTimeout: TimeInterval = 15

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        executionTimeAllowance = 900
        app = XCUIApplication()
        tapCount = 0
    }

    private func launch(_ flags: [String] = [], language: StoreLanguage = .en,
                        paste: String? = nil, qrStoreID: String? = nil, reset: Bool = true) {
        if app.state != .notRunning { app.terminate() }
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(\(language.rawValue))",
                               "-AppleLocale", language.locale] + (reset ? ["-reset"] : []) + flags
        var environment: [String: String] = [:]
        environment["DM_PASTE_CODE"] = paste
        environment["DM_QR_STORE_ID"] = qrStoreID
        app.launchEnvironment = environment
        app.launch()
    }

    private var elements: XCUIElementQuery { app.descendants(matching: .any) }

    private func element(_ id: String) -> XCUIElement { elements.matching(identifier: id).firstMatch }

    private func tap(_ id: String, in query: XCUIElementQuery? = nil) {
        guard let control = scrollToHittable((query ?? elements).matching(identifier: id), id: id) else { return }
        control.tap()
        tapCount += 1
    }

    private func scrollToHittable(_ matches: XCUIElementQuery, id: String) -> XCUIElement? {
        let deadline = ProcessInfo.processInfo.systemUptime + uiTimeout
        var unknownPositionScrolls = 0
        repeat {
            let candidates = matches.allElementsBoundByIndex
            let visible = candidates.filter { $0.isHittable }
            if let enabled = visible.first(where: { $0.isEnabled }) { return enabled }
            if visible.isEmpty {
                let frame = app.frame
                let keyboard = app.keyboards.firstMatch
                let keyboardFrame = keyboard.exists ? keyboard.frame.intersection(frame) : .null
                let bottom = keyboardFrame.isEmpty ? frame.maxY : keyboardFrame.minY
                let visibleHeight = bottom - frame.minY
                if frame.height > 0, visibleHeight > 0 {
                    let towardTop: Bool
                    if let target = candidates.first, !target.frame.isEmpty {
                        towardTop = target.frame.midY < frame.minY + visibleHeight * 0.3
                    } else {
                        towardTop = unknownPositionScrolls % 8 >= 4
                        unknownPositionScrolls += 1
                    }
                    let top = app.coordinate(withNormalizedOffset:
                        CGVector(dx: 0.5, dy: 0.28 * visibleHeight / frame.height))
                    let lower = app.coordinate(withNormalizedOffset:
                        CGVector(dx: 0.5, dy: 0.76 * visibleHeight / frame.height))
                    let start = towardTop ? top : lower
                    let end = towardTop ? lower : top
                    start.press(forDuration: 0.05, thenDragTo: end)
                }
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        } while ProcessInfo.processInfo.systemUptime < deadline
        XCTFail("Couldn't make \(id) hittable and enabled within \(uiTimeout) seconds")
        return nil
    }

    private func assertText(_ id: String) {
        XCTAssertTrue(element(id).waitForExistence(timeout: uiTimeout), id)
    }

    private func waitForKeyboardFocus(_ field: XCUIElement) -> Bool {
        let focused = NSPredicate(format: "exists == YES AND hasKeyboardFocus == YES")
        let expectation = XCTNSPredicateExpectation(predicate: focused, object: field)
        return XCTWaiter.wait(for: [expectation], timeout: uiTimeout) == .completed
    }

    private func focusInput(_ id: String, in fields: XCUIElementQuery,
                            expectsAutomaticFocus: Bool = false) -> XCUIElement? {
        let matches = fields.matching(identifier: id)
        let field = matches.firstMatch
        if expectsAutomaticFocus, !waitForKeyboardFocus(field) {
            XCTFail("\(id) did not receive automatic keyboard focus")
            return nil
        }
        guard let visible = scrollToHittable(matches, id: id) else { return nil }
        visible.tap()
        if !expectsAutomaticFocus { tapCount += 1 }
        guard waitForKeyboardFocus(field) else {
            XCTFail("\(id) did not receive keyboard focus after tapping")
            return nil
        }
        return field
    }

    private func typeInFocusedField(_ id: String, _ text: String, in fields: XCUIElementQuery? = nil) {
        focusInput(id, in: fields ?? app.textFields, expectsAutomaticFocus: true)?.typeText(text)
    }

    private func menuCode(_ json: String) -> String {
        "DM1:" + Data(json.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    }

    private func screenshot(_ name: String) {
        let picture = app.screenshot()
        let item = XCTAttachment(screenshot: picture)
        item.name = name
        item.lifetime = .keepAlways
        add(item)
    }

    func testStartShuffleTimerDoneAndUndo() {
        launch()
        XCTAssertEqual(app.alerts.count, 0)
        assertText("home.activity.2")
        tap("home.activity.0")
        assertText("session.timer")
        tap("session.hide")
        assertText("session.untimed")
        tap("session.back")
        tap("home.resume")
        tap("session.done")
        assertText("done.title")
        tap("done.undo")
        tap("budget.15")
        tap("home.shuffle")
        tap("home.activity.0")
        assertText("session.untimed")
        tap("session.end")
        tap("budget.30")
        tap("home.activity.0")
        assertText("session.activity")
    }

    func testZeroWaitsForCompletionAndSessionRestores() {
        launch(["-timer-zero"])
        tap("home.activity.0")
        assertText("session.timer")
        assertText("session.timeUp")
        XCTAssertFalse(element("done.title").exists)
        tap("session.back")
        tap("home.resume")
        assertText("session.timer")
        launch(reset: false)
        assertText("session.timeUp")
        XCTAssertFalse(element("done.title").exists)
        tap("session.done")
        assertText("done.title")
    }

    func testEditArchiveAndKeepActivityAfterExpiry() {
        launch()
        let addStart = tapCount
        tap("home.add")
        typeInFocusedField("editor.name", "Paper folding")
        tap("editor.save")
        XCTAssertEqual(tapCount - addStart, 2)
        assertText("home.activity.0")

        let durationStart = tapCount
        tap("home.edit.0")
        assertText("editor.name")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: uiTimeout))
        tap("editor.minutes.4")
        XCTAssertEqual(element("editor.duration").label, "Estimated: 4 min")
        tap("editor.save")
        XCTAssertEqual(tapCount - durationStart, 3)

        let renameStart = tapCount
        tap("home.edit.0")
        guard let field = focusInput("editor.name", in: app.textFields) else { return }
        field.typeKey("a", modifierFlags: .command)
        field.typeText("Fold paper")
        let renamed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Fold paper"),
                                                object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [renamed], timeout: uiTimeout), .completed)
        tap("editor.save")
        XCTAssertEqual(tapCount - renameStart, 3)

        let archiveStart = tapCount
        tap("home.menu")
        guard let activity = scrollToHittable(elements.matching(identifier: "menu.activity.0"),
                                               id: "menu.activity.0") else { return }
        activity.swipeLeft()
        if element("menu.archive.0").exists { tap("menu.archive.0") }
        assertText("menu.archived")
        XCTAssertLessThanOrEqual(tapCount - archiveStart, 2)
        tap("menu.back")

        let restoreStart = tapCount
        tap("home.menu")
        tap("archive.restore.0")
        assertText("menu.activity.0")
        XCTAssertEqual(tapCount - restoreStart, 2)
        tap("menu.back")

        tap("home.activity.0")
        tap("session.done")
        assertText("done.title")

        launch(["-expired"], reset: false)
        assertText("home.activity.0")
        XCTAssertFalse(element("filter.low").exists)
        tap("home.menu")
        assertText("menu.activity.0")
        tap("menu.history")
        let record = elements.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "history.record.", "Fold paper"
        )).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: uiTimeout))
    }

    func testAddWithCustomDurationWithinThreeTaps() {
        launch()
        let start = tapCount
        tap("home.add")
        typeInFocusedField("editor.name", "Fold paper")
        tap("editor.minutes.3")
        tap("editor.save")
        XCTAssertEqual(tapCount - start, 3)
        assertText("home.activity.0")
        XCTAssertTrue(element("home.activity.0").label.contains("3 min"))
    }

    func testAddFromStarterWithinThreeTaps() {
        launch()
        let start = tapCount
        tap("home.add")
        tap("starters.activity.0")
        XCTAssertEqual(element("editor.name").value as? String, "Look out the window")
        tap("editor.save")
        XCTAssertEqual(tapCount - start, 3)
        assertText("home.activity.0")
        XCTAssertTrue(element("home.activity.0").label.contains("Look out the window"))

        let rewrite = tapCount
        tap("home.add")
        tap("starters.activity.1")
        typeInFocusedField("editor.name", "!")
        tap("editor.save")
        XCTAssertEqual(tapCount - rewrite, 3)
        tap("home.menu")
        assertText("menu.activity.1")
        XCTAssertTrue(element("menu.activity.1").label.contains("!"))
    }

    func testImportAndShare() {
        let code = menuCode(#"[{"name":"Fold paper","minutes":5},{"name":"FOLD PAPER","minutes":5}]"#)
        launch(paste: "A little downtime. #DopamineMenu\n\n" + code)
        let importStart = tapCount
        tap("home.import")
        tap("import.paste")
        assertText("import.preview")
        tap("import.add")
        assertText("import.success")
        XCTAssertEqual(tapCount - importStart, 3)
        tap("import.back")
        XCTAssertTrue(element("home.activity.0").label.contains("Fold paper"))
        tap("home.edit.0")
        tap("editor.share")
        tap("editor.save")

        let defaultStart = tapCount
        tap("home.share")
        assertText("share.preview")
        tap("share.image")
        assertText("share.requested")
        XCTAssertEqual(tapCount - defaultStart, 2)
        tap("share.back")

        let compactStart = tapCount
        tap("home.share")
        tap("share.layout.compact", in: app.buttons)
        let compactPreview = elements.matching(NSPredicate(
            format: "identifier == %@ AND value == %@", "share.preview", "Compact"
        )).firstMatch
        XCTAssertTrue(compactPreview.waitForExistence(timeout: uiTimeout))
        tap("share.image")
        assertText("share.requested")
        XCTAssertEqual(tapCount - compactStart, 3)
        let caption = element("share.requested").value as? String ?? ""
        XCTAssertTrue(caption.contains("My 5-minute alternatives"))
        XCTAssertTrue(caption.contains("\n\nDM1:"))
        tap("share.copy")
        assertText("share.copied")
        tap("share.file")
        assertText("share.requested")

        launch(paste: caption)
        tap("home.import")
        tap("import.paste")
        assertText("import.preview")
        tap("import.add")
        assertText("import.success")
        tap("import.back")
        XCTAssertTrue(element("home.activity.0").label.contains("Fold paper"))
    }

    func testInvalidCodeAndManualEntry() {
        launch(paste: "DM2:invalid")
        tap("home.import")
        tap("import.paste")
        assertText("import.error")
        XCTAssertFalse(element("import.add").isEnabled)
    }

    func testDeniedPasteFocusesManualEntryWithinThreeTaps() {
        launch(["-paste-denied"])
        let start = tapCount
        tap("home.import")
        tap("import.paste")
        assertText("import.error")
        typeInFocusedField("import.code", menuCode(#"[{"name":"Tea","minutes":5}]"#), in: app.textViews)
        assertText("import.preview")
        tap("import.add")
        assertText("import.success")
        XCTAssertEqual(tapCount - start, 3)
    }

    func testMilestoneUndoAndReviewWhenIdle() {
        launch(["-seed-history"], qrStoreID: "1234567890")
        tap("home.activity.0")
        tap("session.done")
        assertText("done.milestoneTitle")
        let completionShare = tapCount
        tap("done.milestone")
        assertText("share.preview")
        XCTAssertTrue(element("share.preview").label.contains("#DopamineMenu #LittleThings"))
        XCTAssertTrue(element("share.preview").label.contains("Scan to download on the App Store"))
        tap("share.image")
        assertText("share.requested")
        XCTAssertEqual(tapCount - completionShare, 2)
        XCTAssertFalse((element("share.requested").value as? String ?? "").contains("DM1:"))
        tap("share.back")
        tap("done.undo")
        XCTAssertFalse(element("review.requested").exists)
        tap("home.history")
        assertText("history.title")
        XCTAssertFalse(element("history.milestone").exists)
        tap("history.back")
        tap("home.activity.0")
        tap("session.done")
        assertText("done.milestone")
        XCTAssertFalse(element("review.requested").exists)
        tap("done.back")
        assertText("review.requested")

        let shareStart = tapCount
        tap("home.history")
        tap("history.milestone")
        assertText("share.preview")
        tap("share.image")
        assertText("share.requested")
        XCTAssertEqual(tapCount - shareStart, 3)
    }

    func testThirdCompletionDayWaitsForFreshCompletionAndIdleHome() {
        launch(["-seed-review-days"])
        tap("home.add")
        typeInFocusedField("editor.name", "Fold paper")
        tap("editor.save")
        tap("home.activity.0")
        tap("session.done")
        assertText("done.title")
        XCTAssertFalse(element("review.requested").exists)

        launch(reset: false)
        assertText("home.activity.0")
        XCTAssertFalse(element("review.requested").waitForExistence(timeout: uiTimeout))
        tap("home.activity.0")
        tap("session.back")
        tap("filter.low", in: app.buttons)
        assertText("home.empty")
        tap("home.resume")
        tap("session.done")
        tap("done.back")
        assertText("home.empty")
        XCTAssertFalse(element("review.requested").waitForExistence(timeout: uiTimeout))
        tap("filter.low", in: app.buttons)
        XCTAssertFalse(element("review.requested").waitForExistence(timeout: uiTimeout))

        tap("home.activity.0")
        tap("session.done")
        tap("done.back")
        assertText("review.requested")
        XCTAssertEqual(app.alerts.count, 0)

        launch(reset: false)
        tap("home.activity.0")
        tap("session.done")
        tap("done.back")
        XCTAssertFalse(element("review.requested").waitForExistence(timeout: uiTimeout))
    }

    func testFiltersRestoreAfterEntitlementReadFailure() {
        launch()
        tap("home.add")
        tap("starters.activity.0")
        tap("editor.save")
        tap("home.edit.0")
        guard let group = focusInput("editor.group", in: app.textFields) else { return }
        group.typeText("At home")
        tap("editor.save")
        tap("home.add")
        typeInFocusedField("editor.name", "Fold paper")
        tap("editor.save")
        tap("filter.low", in: app.buttons)
        tap("filter.groups")
        tap("filter.group.At home")
        XCTAssertTrue(element("filter.groups").label.contains("At home"))
        XCTAssertFalse(element("home.activity.1").exists)

        launch(["-entitlement-unavailable"], reset: false)
        assertText("home.activity.1")
        XCTAssertFalse(element("filter.low").exists)
        XCTAssertFalse(element("filter.groups").exists)

        launch(reset: false)
        assertText("filter.low")
        XCTAssertTrue(element("filter.low").isSelected)
        XCTAssertTrue(element("filter.groups").label.contains("At home"))
        XCTAssertFalse(element("home.activity.1").exists)
    }

    func testWidgetRoutesAndExpiredDoesNotBlockHome() {
        launch(["-expired", "-widget-15"])
        assertText("budget.15")
        tap("home.widgets")
        assertText("widgets.title")
        tap("widgets.quick")
        assertText("home.activity.2")
        tap("home.activity.0")
        assertText("session.activity")
        tap("session.end")
        tap("home.pro")
        assertText("pro.expired")
        tap("pro.close")
        assertText("home.activity.0")
    }

    func testStoreScreenshots() {
        for lang in StoreLanguage.allCases {
            let prefix = "store-\(lang.rawValue)-"
            launch(language: lang)
            assertText("home.activity.2")
            screenshot(prefix + "01-home")
            tap("home.activity.1")
            assertText("session.timer")
            screenshot(prefix + "02-timer")
            tap("session.end")
            tap("home.add")
            tap("starters.activity.0")
            tap("editor.save")
            tap("home.edit.0")
            assertText("editor.name")
            let archive = app.buttons["editor.archive"]
            let save = app.buttons["editor.save"]
            XCTAssertTrue(archive.waitForExistence(timeout: uiTimeout))
            XCTAssertTrue(archive.isHittable)
            XCTAssertTrue(save.isHittable)
            XCTAssertLessThanOrEqual(archive.frame.maxY, save.frame.minY)
            screenshot(prefix + "03-editor")
            launch(["-widget-guide"], language: lang)
            assertText("widgets.title")
            screenshot(prefix + "04-widgets")
            launch(language: lang)
            tap("home.share")
            assertText("share.preview")
            screenshot(prefix + "05-share")
        }
    }

    func testPaidScreenshot() {
        launch(["-paywall"], language: .hans)
        assertText("paywall.title")
        assertText("pro.buy")
        screenshot("paid-01-paywall")
    }
}
