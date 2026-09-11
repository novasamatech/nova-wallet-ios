import Foundation
import Operation_iOS

protocol LegalDocumentsFetchOperationFactoryProtocol {
    func fetchOperation() -> BaseOperation<LegalDocumentsRemote>
}

/// `consentRequiredWrapper()` collapses a failed documents fetch into `false`, which is
/// indistinguishable from "no consent needed". Callers that must not act on a network blip
/// use this tri-state instead.
enum LegalConsentStatus {
    case required
    case notRequired
    case unavailable
}

protocol LegalConsentRepositoryProtocol: AnyObject {
    func consentRequiredWrapper() -> CompoundOperationWrapper<Bool>

    func legalConsentStatusWrapper() -> CompoundOperationWrapper<LegalConsentStatus>

    func acceptCurrentVersions(deferringWhenUnavailable: Bool)
}
