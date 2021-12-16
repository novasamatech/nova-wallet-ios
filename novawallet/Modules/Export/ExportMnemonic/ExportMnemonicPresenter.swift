import Foundation
import SoraFoundation

final class ExportMnemonicPresenter {
    weak var view: ExportGenericViewProtocol?
    let wireframe: ExportMnemonicWireframeProtocol
    let interactor: ExportMnemonicInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    private(set) var exportData: ExportMnemonicData?

    init(
        interactor: ExportMnemonicInteractorInputProtocol,
        wireframe: ExportMnemonicWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }
}

extension ExportMnemonicPresenter: ExportGenericPresenterProtocol {
    func setup() {
        interactor.fetchExportData()
    }

    func activateExport() {
        guard let exportData = exportData else {
            return
        }

        wireframe.openConfirmationForMnemonic(exportData.mnemonic, from: view)
    }

    func activateAdvancedSettings() {
        guard let exportData = exportData, let accountResponse = exportData.metaAccount.fetch(
            for: exportData.chain.accountRequest()
        ) else {
            return
        }

        let advancedSettings: AdvancedWalletSettings

        if exportData.chain.isEthereumBased {
            advancedSettings = AdvancedWalletSettings.ethereum(
                derivationPath: exportData.derivationPath
            )
        } else {
            let networkSettings = AdvancedNetworkTypeSettings(
                availableCryptoTypes: [accountResponse.cryptoType],
                selectedCryptoType: accountResponse.cryptoType,
                derivationPath: exportData.derivationPath
            )

            advancedSettings = AdvancedWalletSettings.substrate(settings: networkSettings)
        }

        wireframe.showAdvancedSettings(from: view, secretSource: .mnemonic, settings: advancedSettings)
    }
}

extension ExportMnemonicPresenter: ExportMnemonicInteractorOutputProtocol {
    func didReceive(exportData: ExportMnemonicData) {
        self.exportData = exportData

        let viewModel = ExportGenericViewModel(sourceDetails: exportData.mnemonic.toString())
        view?.set(viewModel: viewModel)
    }

    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}
