import Foundation
import Security

final class LocalStore: @unchecked Sendable {
    struct SaveResult: Sendable {
        let saved: Bool
        let published: Bool
    }

    private let worker = DispatchQueue(label: "com.hgsldswk.dopaminemenu.storage", qos: .utility)
    private let testing = Launch.uiTesting
    private let service = "com.hgsldswk.dopaminemenu.entitlement"

    func load(reset: Bool) async throws -> (MenuData, Entitlement) {
        try await withCheckedThrowingContinuation { continuation in
            worker.async {
                do {
                    let folder = try self.folder()
                    let url = folder.appendingPathComponent("menu-v1.json")
                    if reset && self.testing && FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                    let state = FileManager.default.fileExists(atPath: url.path)
                        ? try JSONDecoder().decode(MenuData.self, from: Data(contentsOf: url))
                        : MenuData()
                    let entitlement = self.testing ? Entitlement() : self.loadEntitlement()
                    continuation.resume(returning: (state, entitlement))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func save(_ state: MenuData, publishWidget: Bool, completion: @escaping @Sendable (SaveResult) -> Void) {
        worker.async {
            do {
                let destination = try self.folder().appendingPathComponent("menu-v1.json")
                try JSONEncoder().encode(state).write(to: destination, options: .atomic)
                let published = publishWidget && self.publishWidget(state.budget)
                completion(SaveResult(saved: true, published: published))
            } catch {
                completion(SaveResult(saved: false, published: false))
            }
        }
    }

    private func publishWidget(_ budget: Budget) -> Bool {
        guard !testing,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.group)
        else { return false }
        do {
            let bytes = try JSONEncoder().encode(WidgetSnapshot(budget: budget))
            try bytes.write(to: container.appendingPathComponent(WidgetSnapshot.filename), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func save(_ entitlement: Entitlement) {
        guard !testing else { return }
        worker.async { self.writeEntitlement(entitlement) }
    }

    private func folder() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory,
                                               in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent(testing ? "UITests" : "DopamineMenu", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "v1"]
    }

    private func loadEntitlement() -> Entitlement {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let bytes = item as? Data,
           let cached = try? JSONDecoder().decode(Entitlement.self, from: bytes) { return cached }
        guard status == errSecItemNotFound else {
            return Entitlement(trialRevoked: true)
        }
        let fresh = Entitlement()
        writeEntitlement(fresh)
        return fresh
    }

    private func writeEntitlement(_ entitlement: Entitlement) {
        guard let data = try? JSONEncoder().encode(entitlement) else { return }
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(keychainQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = keychainQuery
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }
}
