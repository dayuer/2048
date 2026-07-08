import Foundation
import Security

/// API Key 存取抽象：真机走钥匙串，测试注入内存版。
protocol SecretStore: Sendable {
    func get(_ account: String) -> String?
    func set(_ value: String, for account: String)
    func remove(_ account: String)
}

/// 钥匙串实现：kSecClassGenericPassword，service 固定，account = 配置 id。
/// Key 永不落 JSON / UserDefaults / iCloud（ThisDeviceOnly）。
struct KeychainSecretStore: SecretStore {
    let service: String

    init(service: String = "com.dayuer.above.llm-keys") {
        self.service = service
    }

    private func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func get(_ account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String, for account: String) {
        guard !value.isEmpty else { return remove(account) }
        let data = Data(value.utf8)
        var query = baseQuery(account)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    func remove(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }
}

/// 内存实现：单测/预览用，进程退出即失。
final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var storage: [String: String] = [:]
    private let lock = NSLock()

    func get(_ account: String) -> String? {
        lock.withLock { storage[account] }
    }

    func set(_ value: String, for account: String) {
        lock.withLock { storage[account] = value.isEmpty ? nil : value }
    }

    func remove(_ account: String) {
        lock.withLock { storage[account] = nil }
    }
}
