import Foundation
import Keystore_iOS

protocol KeychainProxyProtocol: KeystoreProtocol {
    func flushToActual(persistentStore: KeystoreProtocol) throws
}

final class KeychainProxy: KeychainProxyProtocol {
    private var keystore: [String: Data] = [:]

    func flushToActual(persistentStore: KeystoreProtocol) throws {
        try keystore.forEach { keyValue in
            try persistentStore.saveKey(keyValue.value, with: keyValue.key)
        }

        keystore = [:]
    }

    func addKey(_ key: Data, with identifier: String) throws {
        keystore[identifier] = key
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        keystore[identifier] = key
    }

    func fetchKey(for identifier: String) throws -> Data {
        if let data = keystore[identifier] {
            return data
        } else {
            throw KeystoreError.noKeyFound
        }
    }

    func checkKey(for identifier: String) throws -> Bool {
        keystore[identifier] != nil
    }

    func deleteKey(for identifier: String) throws {
        if try checkKey(for: identifier) {
            keystore[identifier] = nil
        } else {
            throw KeystoreError.noKeyFound
        }
    }
}
