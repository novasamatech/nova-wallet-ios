import Foundation
import SoraFoundation

final class AdvancedExportPresenter {
    weak var view: AdvancedExportViewProtocol?
    let wireframe: AdvancedExportWireframeProtocol
    let interactor: AdvancedExportInteractorInputProtocol

    private let localizationManager: LocalizationManagerProtocol
    private let logger: LoggerProtocol

    private let metaAccount: MetaAccountModel
    private var chain: ChainModel?

    private let viewModelFactory: AdvancedExportViewModelFactory
    private let walletViewModelFactory = WalletAccountViewModelFactory()

    init(
        interactor: AdvancedExportInteractorInputProtocol,
        wireframe: AdvancedExportWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol,
        viewModelFactory: AdvancedExportViewModelFactory,
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
}

extension AdvancedExportPresenter: AdvancedExportPresenterProtocol {
    func setup() {
        interactor.requestExportOptions(
            metaAccount: metaAccount,
            chain: chain
        )
        
        guard
            let chain,
            let walletViewModel = try? walletViewModelFactory.createDisplayViewModel(from: metaAccount)
        else {
            return
        }

        view?.updateNavbar(with: walletViewModel)
    }
}

extension AdvancedExportPresenter: AdvancedExportInteractorOutputProtocol {
    func didReceive(exportData: AdvancedExportData) {
        let viewModel = viewModelFactory.createViewModel(
            for: exportData,
            chain: chain,
            selectedLocale: localizationManager.selectedLocale,
            onTapSubstrateSecret: { [weak self] in self?.didTapSubstrateSecretCover() },
            onTapEthereumSecret: { [weak self] in self?.didTapEthereumSecretCover() },
            onTapExportJSON: { [weak self] in self?.wireframe.showExportRestoreJSON(from: self?.view) }
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

// MARK: Private

private extension AdvancedExportPresenter {
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
