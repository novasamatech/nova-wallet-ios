import Foundation

final class LegalConsentInteractor {
    let legalConsentRepository: LegalConsentRepositoryProtocol

    init(legalConsentRepository: LegalConsentRepositoryProtocol) {
        self.legalConsentRepository = legalConsentRepository
    }
}

// MARK: - LegalConsentInteractorInputProtocol

extension LegalConsentInteractor: LegalConsentInteractorInputProtocol {
    func acceptCurrentVersions() {
        // The sheet only opens after a successful `isConsentRequired`, so the cache is warm and the
        // flag is irrelevant here.
        legalConsentRepository.acceptCurrentVersions(deferringWhenUnavailable: true)
    }
}
