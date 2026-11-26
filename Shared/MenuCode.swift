import Foundation

struct MenuCode {
    static let prefix = "DM1:"
    static let limit = 12
    static let maxLength = 3072
    static let maxInputLength = maxLength + 1024

    struct Item: Codable, Hashable {
        var name: String
        var minutes: Int

        var activity: Activity { Activity(name: name, minutes: minutes) }
        var identity: Item {
            let folded = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
                .precomposedStringWithCanonicalMapping
                .folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            return Item(name: folded, minutes: minutes)
        }
    }

    struct Merge {
        var newItems: [Item]
        var duplicates: Int
    }

    enum Invalid: Error { case version, length, contents }

    static func validName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        name.count <= 48 && name.utf8.count <= 144 &&
        name.unicodeScalars.allSatisfy {
            !CharacterSet.controlCharacters.contains($0) || $0.value == 0x200C || $0.value == 0x200D
        }
    }

    static func encode(_ items: [Item]) throws -> String {
        try validate(items)
        let data = try JSONEncoder().encode(items)
        let code = prefix + data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        guard code.utf8.count <= maxLength else { throw Invalid.length }
        return code
    }

    static func decode(_ raw: String) throws -> [Item] {
        guard raw.utf8.count <= maxInputLength else { throw Invalid.length }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let code: String
        if text.contains(where: \.isNewline) {
            let codeLines = text.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix(prefix) }
            guard !codeLines.isEmpty else { throw Invalid.version }
            guard codeLines.count == 1 else { throw Invalid.contents }
            code = codeLines[0]
        } else {
            code = text
        }
        guard code.utf8.count <= maxLength else { throw Invalid.length }
        guard code.hasPrefix(prefix) else { throw Invalid.version }
        let body = code.dropFirst(prefix.count)
        let alphabet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        guard body.unicodeScalars.allSatisfy(alphabet.contains) else { throw Invalid.contents }
        var padded = body.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        padded += String(repeating: "=", count: (4 - padded.count % 4) % 4)
        guard let data = Data(base64Encoded: padded),
              let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]],
              rows.allSatisfy({ Set($0.keys) == ["name", "minutes"] }),
              let items = try? JSONDecoder().decode([Item].self, from: data) else { throw Invalid.contents }
        try validate(items)
        return items.map { Item(name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping, minutes: $0.minutes) }
    }

    static func merge(_ items: [Item], existing: [Activity]) -> Merge {
        var seen = Set(existing.map { Item(name: $0.name, minutes: $0.minutes).identity })
        let fresh = items.filter { seen.insert($0.identity).inserted }
        return Merge(newItems: fresh, duplicates: items.count - fresh.count)
    }

    private static func validate(_ items: [Item]) throws {
        guard (1...limit).contains(items.count),
              items.allSatisfy({ validName($0.name) && (1...30).contains($0.minutes) })
        else { throw Invalid.contents }
    }
}
