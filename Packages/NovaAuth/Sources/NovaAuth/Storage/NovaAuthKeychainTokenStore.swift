import Foundation
import Security
import CryptoKit

protocol NovaAuthSecurityProtocol {
    func copy(_ query: [String: Any]) -> (OSStatus, Data?)
    func add(_ query: [String: Any]) -> OSStatus
    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus
    func delete(_ query: [String: Any]) -> OSStatus
}

struct NovaAuthSecurity: NovaAuthSecurityProtocol {
    func copy(_ query: [String: Any]) -> (OSStatus, Data?) {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result as? Data)
    }

    func add(_ query: [String: Any]) -> OSStatus { SecItemAdd(query as CFDictionary, nil) }
    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    func delete(_ query: [String: Any]) -> OSStatus { SecItemDelete(query as CFDictionary) }
}

final class NovaAuthKeychainTokenStore: NovaAuthTokenStoreProtocol {
    private let security: NovaAuthSecurityProtocol
    private let mutationLock = NSLock()

    init(security: NovaAuthSecurityProtocol = NovaAuthSecurity()) {
        self.security = security
    }

    func load() throws -> NovaAuthTokenRecord? { try loadRecord() }

    func replace(_ record: NovaAuthTokenRecord) throws {
        try mutationLock.novaAuthLocked {
            let data = try encoded(record)
            let query = scopedQuery()
            let attributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrGeneric as String: Data(SHA256.hash(data: data)),
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            var status = security.update(query, attributes: attributes)
            if status == errSecItemNotFound {
                status = security.add(query.merging(attributes) { _, new in new })
            }
            guard status == errSecSuccess else { throw NovaAuthError.storageUnavailable }
        }
    }

    @discardableResult func remove(ifMatching record: NovaAuthTokenRecord) throws -> Bool {
        var query = scopedQuery()
        query[kSecAttrGeneric as String] = Data(SHA256.hash(data: try encoded(record)))
        let status = security.delete(query)
        if status == errSecItemNotFound { return false }
        guard status == errSecSuccess else { throw NovaAuthError.storageUnavailable }
        return true
    }

    func removeAll() throws { try mutationLock.novaAuthLocked { try deleteAll() } }
}

private extension NovaAuthKeychainTokenStore {
    func scopedQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "io.novawallet.novaauth.profile3",
         kSecAttrAccount as String: "current"]
    }

    func encoded(_ record: NovaAuthTokenRecord) throws -> Data {
        do {
            try NovaAuthStoredValidation.token(record)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(record)
        } catch { throw NovaAuthError.storageUnavailable }
    }

    func loadRecord() throws -> NovaAuthTokenRecord? {
        var query = scopedQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let (status, data) = security.copy(query)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw NovaAuthError.storageUnavailable }
        do {
            guard let data, data.count <= 16384 else { throw NovaAuthError.storageUnavailable }
            let record = try JSONDecoder().decode(NovaAuthTokenRecord.self, from: data)
            try NovaAuthStoredValidation.token(record)
            return record
        } catch {
            return nil
        }
    }

    func deleteAll() throws {
        let status = security.delete(scopedQuery())
        guard status == errSecSuccess || status == errSecItemNotFound else { throw NovaAuthError.storageUnavailable }
    }
}
