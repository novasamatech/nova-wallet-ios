import Foundation
import Keystore_iOS

class TestSecretStoreManager: SecretStoreManagerProtocol {
    func loadSecret(for identifier: String,
                    completionQueue: DispatchQueue,
                    completionBlock: @escaping (SecretDataRepresentable?) -> Void) {}

    func saveSecret(_ secret: SecretDataRepresentable,
                    for identifier: String,
                    completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {}

    func removeSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {}

    func checkSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {}

    func checkSecret(for identifier: String) -> Bool {
        true
    }
}
