import Foundation
import Operation_iOS

protocol LegalDocumentsFetchOperationFactoryProtocol {
    func fetchOperation() -> BaseOperation<LegalDocumentsRemote>
}

protocol LegalConsentRepositoryProtocol: AnyObject {
    /// Answers `true` only when the remote config loaded and some document's remote version is
    /// strictly greater than the locally accepted one.
    ///
    /// Any failure — no network, 404, malformed JSON, missing key, malformed date — answers `false`:
    /// the app must never prompt on a config it could not read. Concurrent calls coalesce into a
    /// single network request.
    func isConsentRequired(runningIn queue: DispatchQueue, completion: @escaping (Bool) -> Void)

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
