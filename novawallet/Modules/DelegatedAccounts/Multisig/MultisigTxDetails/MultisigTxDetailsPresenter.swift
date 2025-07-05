import Foundation
import Foundation_iOS

final class MultisigTxDetailsPresenter {
    weak var view: MultisigTxDetailsViewProtocol?
    let wireframe: MultisigTxDetailsWireframeProtocol
    let interactor: MultisigTxDetailsInteractorInputProtocol
    let viewModelFactory: MultisigTxDetailsViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol?

    let chain: ChainModel

    var priceData: PriceData?
    var txDetails: MultisigTxDetails?
    var prettifiedCallString: String?

    init(
        interactor: MultisigTxDetailsInteractorInputProtocol,
        wireframe: MultisigTxDetailsWireframeProtocol,
        viewModelFactory: MultisigTxDetailsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        chain: ChainModel,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
        self.chain = chain
        self.logger = logger
    }
}

// MARK: - Private

private extension MultisigTxDetailsPresenter {
    func provideViewModel() {
        guard
            let txDetails,
            let chainAsset = chain.utilityChainAsset()
        else { return }

        let viewModel = viewModelFactory.createViewModel(
            multisigTxDetails: txDetails,
            depositAsset: chainAsset,
            assetPrice: priceData,
            prettifiedJsonString: prettifiedCallString,
            locale: localizationManager.selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }

    func provideDeposit() {
        guard
            let txDetails,
            let chainAsset = chain.utilityChainAsset()
        else { return }

        let viewModel = viewModelFactory.createDepositViewModel(
            multisigTxDetails: txDetails,
            depositAsset: chainAsset,
            assetPrice: priceData,
            locale: localizationManager.selectedLocale
        )

        view?.didReceive(depositViewModel: viewModel)
    }
}

// MARK: - MultisigTxDetailsPresenterProtocol

extension MultisigTxDetailsPresenter: MultisigTxDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

// MARK: - MultisigTxDetailsInteractorOutputProtocol

extension MultisigTxDetailsPresenter: MultisigTxDetailsInteractorOutputProtocol {
    func didReceive(prettifiedCallString: String) {
        self.prettifiedCallString = prettifiedCallString
        provideViewModel()
    }

    func didReceive(txDetails: MultisigTxDetails) {
        self.txDetails = txDetails
        provideViewModel()
    }

    func didReceive(error: any Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            logger?.error("Display result error: \(error)")
        }
    }

    func didReceive(priceData: PriceData?) {
        self.priceData = priceData
        provideDeposit()
    }
}
