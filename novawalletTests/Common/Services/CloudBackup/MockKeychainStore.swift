import Foundation
import Keystore_iOS

public final class MockKeychain: KeystoreProtocol {
    private var keystore: [String: Data] = [:]

    public init() {}

    public init(rawStore: [String: Data]) {
        keystore = rawStore
    }

    public func addKey(_ key: Data, with identifier: String) throws {
        keystore[identifier] = key
    }

    public func updateKey(_ key: Data, with identifier: String) throws {
        keystore[identifier] = key
    }

    public func fetchKey(for identifier: String) throws -> Data {
        if let data = keystore[identifier] {
            return data
        } else {
            throw KeystoreError.noKeyFound
        }
    }

    public func checkKey(for identifier: String) throws -> Bool {
        keystore[identifier] != nil
    }

    public func deleteKey(for identifier: String) throws {
        if try checkKey(for: identifier) {
            keystore[identifier] = nil
        } else {
            throw KeystoreError.noKeyFound
        }
    }

    public func getRawStore() -> [String: Data] {
        keystore
    }
}

extension MockKeychain: SecretStoreManagerProtocol {
    public func loadSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (SecretDataRepresentable?) -> Void
    ) {
        completionQueue.async {
            completionBlock(self.keystore[identifier])
        }
    }

    public func saveSecret(
        _ secret: SecretDataRepresentable,
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        keystore[identifier] = secret.asSecretData()

        completionQueue.async {
            completionBlock(true)
        }
    }

    public func removeSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        keystore[identifier] = nil

        completionQueue.async {
            completionBlock(true)
        }
    }

    public func checkSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        let exists = keystore[identifier] != nil

        completionQueue.async {
            completionBlock(exists)
        }
    }

    public func checkSecret(for identifier: String) -> Bool {
        keystore[identifier] != nil
    }
}
