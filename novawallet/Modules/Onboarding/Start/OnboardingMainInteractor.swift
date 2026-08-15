import Foundation
import SubstrateSdk
import Foundation_iOS

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainInteractorOutputProtocol?

    let secretImportService: SecretImportServiceProtocol
    let walletMigrationService: WalletMigrationServiceProtocol
    let legalConsentRepository: LegalConsentRepositoryProtocol
    let walletSettings: SelectedWalletSettings

    init(
        secretImportService: SecretImportServiceProtocol,
        walletMigrationService: WalletMigrationServiceProtocol,
        legalConsentRepository: LegalConsentRepositoryProtocol,
        walletSettings: SelectedWalletSettings
    ) {
        self.secretImportService = secretImportService
        self.walletMigrationService = walletMigrationService
        self.legalConsentRepository = legalConsentRepository
        self.walletSettings = walletSettings
    }
}

// MARK: - Private

private extension OnboardingMainInteractor {
    func setupWalletMigration() {
        walletMigrationService.addObserver(self)
    }

    func checkPendingWalletMigration() {
        guard let message = walletMigrationService.consumePendingMessage() else {
            return
        }

        handleMigration(message: message)
    }

    func handleMigration(message: WalletMigrationMessage) {
        switch message {
        case let .start(model):
            presenter?.didSuggestWalletMigration(with: model)
        default:
            break
        }
    }

    func suggestSecretImportIfNeeded() {
        guard let definition = secretImportService.definition else {
            return
        }

        switch definition {
        case .keystore:
            presenter?.didSuggestSecretImport(source: .keystore)
        case .mnemonic:
            presenter?.didSuggestSecretImport(source: .mnemonic(.appDefault))
        }
    }

    func recordConsent() {
        legalConsentRepository.acceptCurrentVersions(
            deferringWhenUnavailable: !walletSettings.hasValue
        )
    }
}

// MARK: - OnboardingMainInteractorInputProtocol

extension OnboardingMainInteractor: OnboardingMainInteractorInputProtocol {
    func setup() {
        secretImportService.add(observer: self)
        suggestSecretImportIfNeeded()

        setupWalletMigration()
        checkPendingWalletMigration()
    }

    func acceptLegalDocuments() {
        recordConsent()
    }
}

// MARK: - SecretImportObserver

extension OnboardingMainInteractor: SecretImportObserver {
    func didUpdateDefinition(from _: SecretImportDefinition?) {
        suggestSecretImportIfNeeded()
    }

    func didReceiveError(secretImportError: Error & ErrorContentConvertible) {
        presenter?.didReceiveError(secretImportError)
    }
}

// MARK: - WalletMigrationObserver

extension OnboardingMainInteractor: WalletMigrationObserver {
    func didReceiveMigration(message: WalletMigrationMessage) {
        handleMigration(message: message)
    }
}
