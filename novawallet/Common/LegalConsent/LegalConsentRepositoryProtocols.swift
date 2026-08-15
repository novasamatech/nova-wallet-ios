import Foundation
import Operation_iOS

protocol LegalDocumentsFetchOperationFactoryProtocol {
    func fetchOperation() -> BaseOperation<LegalDocumentsRemote>
}

protocol LegalConsentRepositoryProtocol: AnyObject {
    /// Resolves to `true` only when the remote config loaded and some document's remote version is
    /// strictly greater than the locally accepted one.
    ///
    /// Any failure — no network, 404, malformed JSON, missing key, malformed date — resolves to
    /// `false` rather than erroring: the app must never prompt on a config it could not read, and
    /// keeping that invariant here means no caller can forget it. Once the config has loaded the
    /// wrapper is resolved from the cache without touching the network.
    func consentRequiredWrapper() -> CompoundOperationWrapper<Bool>

    /// Records acceptance of both documents at once. Synchronous on purpose: callers record consent
    /// and navigate on the very next line with the write already durable.
    ///
    /// - Parameter deferringWhenUnavailable: when the config has not loaded yet, `true` arms the
    ///   pending sync flag so the first successful fetch redeems it (the onboarding case) and
    ///   `false` records nothing. Callers that are not genuinely onboarding pass `false` so an
    ///   already onboarded user cannot silently auto accept a revision they never saw — they still
    ///   write real versions when the config is already cached.
    func acceptCurrentVersions(deferringWhenUnavailable: Bool)
}
