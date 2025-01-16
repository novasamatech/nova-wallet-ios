import Foundation
import Foundation_iOS

class BaseExportPresenter {
    weak var view: ExportViewProtocol?
    let wireframe: ExportWireframeProtocol
    let interactor: ExportInteractorInputProtocol

    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol

    let metaAccount: MetaAccountModel
    var chain: ChainModel?

    let viewModelFactory: ExportViewModelFactory

    required init(
        interactor: ExportInteractorInputProtocol,
        wireframe: ExportWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol,
        viewModelFactory: ExportViewModelFactory,
        metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
        self.logger = logger
        self.viewModelFactory = viewModelFactory
        self.metaAccount = metaAccount
        self.chain = chain
    }

    func updateViewNavbar() {
        fatalError("Method must be overriden by child class")
    }

    func didTapSubstrateRestoreJson() {
        wireframe.showExportRestoreJSON(
            from: view,
            wallet: metaAccount,
            chain: chain
        )
    }

    func didTapSubstrateSecretCover() {
        interactor.requestSeedForSubstrate(
            metaAccount: metaAccount,
            chain: chain
        )
    }

    func didTapEthereumSecretCover() {
        interactor.requestKeyForEthereum(
            metaAccount: metaAccount,
            chain: chain
        )
    }
}

extension BaseExportPresenter: ExportPresenterProtocol {
    func setup() {
        interactor.requestExportOptions(
            metaAccount: metaAccount,
            chain: chain
        )

        updateViewNavbar()
    }
}

extension BaseExportPresenter: ExportInteractorOutputProtocol {
    func didReceive(exportData: ExportData) {
        let viewModel = viewModelFactory.createViewModel(
            for: exportData,
            chain: chain,
            selectedLocale: localizationManager.selectedLocale,
            onTapSubstrateSecret: { [weak self] in self?.didTapSubstrateSecretCover() },
            onTapEthereumSecret: { [weak self] in self?.didTapEthereumSecretCover() },
            onTapExportJSON: { [weak self] in self?.didTapSubstrateRestoreJson() }
        )

        view?.update(with: viewModel)
    }

    func didReceive(
        seed: Data,
        for chainName: String
    ) {
        view?.showSecret(
            seed.toHexWithPrefix(),
            for: chainName
        )
    }

    func didReceive(_ error: Error) {
        logger.error("Did receive error: \(error)")

        if !wireframe.present(
            error: error,
            from: view,
            locale: localizationManager.selectedLocale
        ) {
            _ = wireframe.present(
                error: CommonError.dataCorruption,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}
