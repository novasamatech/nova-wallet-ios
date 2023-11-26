import Foundation
import SubstrateSdk

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainInteractorOutputProtocol?

    let keystoreImportService: KeystoreImportServiceProtocol

    init(keystoreImportService: KeystoreImportServiceProtocol) {
        self.keystoreImportService = keystoreImportService
    }

    private func suggestSecretImportIfNeeded() {
        guard let definition = keystoreImportService.definition else {
            return
        }

        switch definition {
        case .keystore:
            presenter?.didSuggestSecretImport(source: .keystore)
        case .mnemonic:
            presenter?.didSuggestSecretImport(source: .mnemonic)
        }
    }
}

extension OnboardingMainInteractor: OnboardingMainInteractorInputProtocol {
    func setup() {
        keystoreImportService.add(observer: self)
        suggestSecretImportIfNeeded()
    }
}

extension OnboardingMainInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from _: SecretImportDefinition?) {
        suggestSecretImportIfNeeded()
    }

    func didReceiveError(secretImportError: Error & ErrorContentConvertible) {
        presenter?.didReceiveError(secretImportError)
    }
}
