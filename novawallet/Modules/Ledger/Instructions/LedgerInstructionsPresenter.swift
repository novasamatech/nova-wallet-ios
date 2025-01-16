import Foundation
import Foundation_iOS

final class LedgerInstructionsPresenter {
    weak var view: LedgerInstructionsViewProtocol?
    let wireframe: LedgerInstructionsWireframeProtocol

    let applicationConfig: ApplicationConfigProtocol
    let isGenericAvailable: Bool
    let walletType: LedgerWalletType

    init(
        wireframe: LedgerInstructionsWireframeProtocol,
        walletType: LedgerWalletType,
        isGenericAvailable: Bool,
        applicationConfig: ApplicationConfigProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.applicationConfig = applicationConfig
        self.walletType = walletType
        self.isGenericAvailable = isGenericAvailable
        self.localizationManager = localizationManager
    }

    private func provideMigrationViewModelIfNeeded() {
        if isGenericAvailable, walletType.isLegacy {
            view?.didReceive(migrationViewModel: .createLedgerMigrationDownload(
                for: selectedLocale
            ) { [weak self] in
                self?.showMigrationDetails()
            })
        }
    }

    private func showMigrationDetails() {
        show(url: applicationConfig.ledgerMigrationURL)
    }

    private func show(url: URL) {
        guard let view = view else {
            return
        }

        wireframe.showWeb(
            url: url,
            from: view,
            style: .automatic
        )
    }
}

extension LedgerInstructionsPresenter: LedgerInstructionsPresenterProtocol {
    func setup() {
        provideMigrationViewModelIfNeeded()
    }

    func showHint() {
        show(url: applicationConfig.ledgerGuideURL)
    }

    func proceed() {
        wireframe.showOnContinue(from: view)
    }
}

extension LedgerInstructionsPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideMigrationViewModelIfNeeded()
        }
    }
}
