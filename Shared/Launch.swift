import Foundation

enum Launch {
    static let freePeriod = false
    static let proID = "com.hgsldswk.dopaminemenu.pro"
    static let trialID = "com.hgsldswk.dopaminemenu.trial"

    #if DEBUG
    static let uiTesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
    #else
    static let uiTesting = false
    #endif

    static func testFlag(_ flag: String) -> Bool {
        uiTesting && ProcessInfo.processInfo.arguments.contains(flag)
    }

    static func testValue(_ key: String) -> String? {
        uiTesting ? ProcessInfo.processInfo.environment[key] : nil
    }
}
