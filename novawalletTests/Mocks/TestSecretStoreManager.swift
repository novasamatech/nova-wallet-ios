import Foundation
import Keystore_iOS

/**
 * Since Cuckoo v2 working only in sandbox we can't refer files from 3rd party as previously. To create a mock:
 *  1) Add a Test class with dummy implementation that inherits class or implements protocol to mock from the library
 *  2) Add path to the Test class to the Cuckoofile.toml
 */
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
