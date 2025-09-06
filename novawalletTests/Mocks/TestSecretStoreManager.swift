import Foundation
import Keystore_iOS

/**
 * Since Cuckoo v2 working only in sandbox we can't refer files from 3rd party as previously. To create a mock:
 *  1) Add a Test class with dummy implementation that inherits class or implements protocol to mock from the library
 *  2) Add path to the Test class to the Cuckoofile.toml
 */
class TestSecretStoreManager: SecretStoreManagerProtocol {
    func loadSecret(
        for _: String,
        completionQueue _: DispatchQueue,
        completionBlock _: @escaping (SecretDataRepresentable?) -> Void
    ) {}

    func saveSecret(
        _: SecretDataRepresentable,
        for _: String,
        completionQueue _: DispatchQueue,
        completionBlock _: @escaping (Bool) -> Void
    ) {}

    func removeSecret(for _: String, completionQueue _: DispatchQueue, completionBlock _: @escaping (Bool) -> Void) {}

    func checkSecret(for _: String, completionQueue _: DispatchQueue, completionBlock _: @escaping (Bool) -> Void) {}

    func checkSecret(for _: String) -> Bool {
        true
    }
}
