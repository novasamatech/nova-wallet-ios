import Foundation

final class ExportRestoreJsonPresenter {
    weak var view: ExportGenericViewProtocol?
    let wireframe: ExportRestoreJsonWireframeProtocol

    let model: RestoreJson

    init(wireframe: ExportRestoreJsonWireframeProtocol, model: RestoreJson) {
        self.wireframe = wireframe
        self.model = model
    }
}

extension ExportRestoreJsonPresenter: ExportGenericPresenterProtocol {
    func setup() {
        let viewModel = ExportGenericViewModel(sourceDetails: model.data)
        view?.set(viewModel: viewModel)
    }

    func activateExport() {
        wireframe.share(
            source: TextSharingSource(message: model.data),
            from: view
        ) { [weak self] completed in
            if completed {
                self?.wireframe.close(view: self?.view)
            }
        }
    }

    func activateAdvancedSettings() {
        let advancedSettings: AdvancedWalletSettings

        if model.chain.isEthereumBased {
            advancedSettings = AdvancedWalletSettings.ethereum(derivationPath: nil)
        } else {
            let networkSettings = AdvancedNetworkTypeSettings(
                availableCryptoTypes: [model.cryptoType],
                selectedCryptoType: model.cryptoType,
                derivationPath: nil
            )

            advancedSettings = AdvancedWalletSettings.substrate(settings: networkSettings)
        }

        wireframe.showAdvancedSettings(from: view, secretSource: .keystore, settings: advancedSettings)
    }
}
