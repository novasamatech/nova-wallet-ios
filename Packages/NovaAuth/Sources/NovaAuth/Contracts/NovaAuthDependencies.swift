import Foundation
import SDKLogger

struct NovaAuthDependencies {
    let appAttest: NovaAuthAppAttestProtocol
    let identityStore: NovaAuthIdentityStoreProtocol
    let tokenStore: NovaAuthTokenStoreProtocol
    let clock: NovaAuthClockProtocol
    let random: NovaAuthRandomProtocol
    let bootstrap: NovaAuthBootstrapProtocol
    let http: NovaAuthHTTPProtocol
    let ownerQueue: OperationQueue
    let bootstrapQueue: OperationQueue
    let requestQueue: OperationQueue
    let appIdentity: NovaAuthAppIdentity
    let logger: SDKLoggerProtocol?
}

struct NovaAuthReaderDependencies {
    let origin: NovaAuthOrigin
    let tokenStore: NovaAuthTokenStoreProtocol
    let clock: NovaAuthClockProtocol
    let http: NovaAuthHTTPProtocol
    let requestQueue: OperationQueue
}
