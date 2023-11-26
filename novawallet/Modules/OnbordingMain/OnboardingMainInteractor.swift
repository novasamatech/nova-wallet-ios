import Foundation
import SubstrateSdk

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainInteractorOutputProtocol?

    let keystoreImportService: KeystoreImportServiceProtocol

    init(keystoreImportService: KeystoreImportServiceProtocol) {
        self.keystoreImportService = keystoreImportService
    }
}

extension OnboardingMainInteractor: OnboardingMainInteractorInputProtocol {
    func setup() {
        keystoreImportService.add(observer: self)

        if keystoreImportService.definition != nil {
            presenter?.didSuggestKeystoreImport()
        }
    }
}

extension OnboardingMainInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from _: SecretImportDefinition?) {
        if keystoreImportService.definition != nil {
            presenter?.didSuggestKeystoreImport()
        }
    }

    func didReceiveError(secretImportError: Error & ErrorContentConvertible) {
        presenter?.didReceiveError(secretImportError)
    }
}
