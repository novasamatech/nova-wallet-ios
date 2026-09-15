import Foundation
import Operation_iOS

/// Resolves the Nova infrastructure base URL the analytics and attestation chains post to.
///
/// The value is published remotely rather than compiled in, so it is only known after a fetch.
/// Everything that needs it therefore resolves it at the head of its own chain; events queue
/// regardless, so a URL that is not yet available delays delivery rather than losing anything.
public protocol AnalyticsInfraURLProviding {
    func createInfraURLWrapper() -> CompoundOperationWrapper<URL>
}
