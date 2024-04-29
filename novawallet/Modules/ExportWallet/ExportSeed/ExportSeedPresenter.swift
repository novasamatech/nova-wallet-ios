import Foundation
import SoraFoundation

final class ExportSeedPresenter {
    weak var view: ExportGenericViewProtocol?
    let wireframe: ExportSeedWireframeProtocol
    let interactor: ExportSeedInteractorInputProtocol
    let localizationManager: LocalizationManager

    private(set) var exportData: ExportSeedData?

    init(
        interactor: ExportSeedInteractorInputProtocol,
        wireframe: ExportSeedWireframeProtocol,
        localizationManager: LocalizationManager
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }
}

extension ExportSeedPresenter: ExportGenericPresenterProtocol {
    func setup() {
        interactor.fetchExportData()
    }

    func activateExport() {}

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

        wireframe.showAdvancedSettings(from: view, secretSource: .seed, settings: advancedSettings)
    }
}

extension ExportSeedPresenter: ExportSeedInteractorOutputProtocol {
    func didReceive(exportData: ExportSeedData) {
        self.exportData = exportData

        let viewModel = ExportGenericViewModel(
            sourceDetails: exportData.seed.toHex(includePrefix: true)
        )

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
