import Foundation

enum Budget: Int, Codable, CaseIterable, Identifiable {
    case five = 5, fifteen = 15, thirty = 30

    var id: Int { rawValue }
    var lowerBand: Int {
        switch self {
        case .five: return 1
        case .fifteen: return 6
        case .thirty: return 16
        }
    }
}

enum WidgetRoute: Equatable {
    case remembered
    case timed(Budget)

    var url: URL {
        var parts = URLComponents()
        parts.scheme = "dopaminemenu"
        parts.host = "pick"
        if case .timed(let budget) = self { parts.path = "/\(budget.rawValue)" }
        return parts.url!
    }

    init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "dopaminemenu", parts.host == "pick",
              parts.query == nil, parts.fragment == nil, parts.port == nil,
              parts.user == nil, parts.password == nil else { return nil }
        switch parts.percentEncodedPath {
        case "", "/": self = .remembered
        case "/5": self = .timed(.five)
        case "/15": self = .timed(.fifteen)
        case "/30": self = .timed(.thirty)
        default: return nil
        }
    }
}

struct WidgetSnapshot: Codable, Equatable {
    static let group = "group.com.hgsldswk.dopaminemenu"
    static let filename = "widget-menu-v1.json"

    var version = 1
    var budget: Budget

    static func read() -> Budget {
        guard let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
              let bytes = try? Data(contentsOf: folder.appendingPathComponent(filename)),
              let snapshot = try? JSONDecoder().decode(Self.self, from: bytes),
              snapshot.version == 1 else { return .five }
        return snapshot.budget
    }
}
