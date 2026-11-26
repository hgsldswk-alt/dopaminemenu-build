import Foundation

final class LocalizationBundleMarker: NSObject {}

enum L {
    static func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: Bundle(for: LocalizationBundleMarker.self), comment: "")
    }

    static func f(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: .current, arguments: args)
    }
}
