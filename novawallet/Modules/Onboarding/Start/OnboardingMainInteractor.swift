import Foundation
import SubstrateSdk
import Foundation_iOS

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainInteractorOutputProtocol?

    let keystoreImportService: KeystoreImportServiceProtocol
    let walletMigrationService: WalletMigrationServiceProtocol

    init(
        keystoreImportService: KeystoreImportServiceProtocol,
        walletMigrationService: WalletMigrationServiceProtocol
    ) {
        self.keystoreImportService = keystoreImportService
        self.walletMigrationService = walletMigrationService
    }

    private func setupWalletMigration() {
        walletMigrationService.addObserver(self)
    }

    private func checkPendingWalletMigration() {
        guard let message = walletMigrationService.consumePendingMessage() else {
            return
        }

        handleMigration(message: message)
    }

    private func handleMigration(message: WalletMigrationMessage) {
        switch message {
        case let .start(model):
            presenter?.didSuggestWalletMigration(with: model)
        default:
            break
        }
    }

    private func suggestSecretImportIfNeeded() {
        guard let definition = keystoreImportService.definition else {
            return
        }

        switch definition {
        case .keystore:
            presenter?.didSuggestSecretImport(source: .keystore)
        case .mnemonic:
            presenter?.didSuggestSecretImport(source: .mnemonic(.appDefault))
        }
    }
}

extension OnboardingMainInteractor: OnboardingMainInteractorInputProtocol {
    func setup() {
        keystoreImportService.add(observer: self)
        suggestSecretImportIfNeeded()

        setupWalletMigration()
        checkPendingWalletMigration()
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

extension OnboardingMainInteractor: WalletMigrationObserver {
    func didReceiveMigration(message: WalletMigrationMessage) {
        handleMigration(message: message)
    }
}
