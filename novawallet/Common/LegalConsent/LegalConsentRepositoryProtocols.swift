import Foundation
import Operation_iOS

protocol LegalDocumentsFetchOperationFactoryProtocol {
    func fetchOperation() -> BaseOperation<LegalDocumentsRemote>
}

protocol LegalConsentRepositoryProtocol: AnyObject {
    func consentRequiredWrapper() -> CompoundOperationWrapper<Bool>

    func acceptCurrentVersions(deferringWhenUnavailable: Bool)
}
