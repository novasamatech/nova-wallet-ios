import Foundation
import NovaAuth

/// The extension can consume the shared current bearer; it has no issuer or App Attest dependency.
enum NovaAuthReaderFactory {
    static func create(origin: NovaAuthOrigin, requestQueue: OperationQueue) throws -> NovaAuthReader {
        guard let sharedStore = SharedContainerGroup.novaAuthStore else {
            throw NovaAuthError.invalidConfiguration
        }
        return NovaAuthReader(configuration: NovaAuthReaderConfiguration(
            origin: origin, sharedStore: sharedStore, requestQueue: requestQueue
        ))
    }
}
