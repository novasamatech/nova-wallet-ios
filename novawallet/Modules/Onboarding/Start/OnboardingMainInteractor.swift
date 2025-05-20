import Foundation
import SubstrateSdk

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainInteractorOutputProtocol?

    let keystoreImportService: KeystoreImportServiceProtocol
    let walletMigrationService: WalletMigrationServiceProtocol
    let eventCenter: EventCenterProtocol

    init(
        keystoreImportService: KeystoreImportServiceProtocol,
        walletMigrationService: WalletMigrationServiceProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.keystoreImportService = keystoreImportService
        self.walletMigrationService = walletMigrationService
        self.eventCenter = eventCenter
    }

    private func setupWalletMigration() {
        walletMigrationService.delegate = self
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
            // post other messages to
            eventCenter.notify(with: WalletMigrationEvent(message: message))
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
            presenter?.didSuggestSecretImport(source: .mnemonic)
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

extension OnboardingMainInteractor: WalletMigrationDelegate {
    func didReceiveMigration(message: WalletMigrationMessage) {
        handleMigration(message: message)
    }
}
