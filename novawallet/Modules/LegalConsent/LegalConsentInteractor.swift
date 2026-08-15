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
        legalConsentRepository.acceptCurrentVersions(deferringWhenUnavailable: true)
    }
}
