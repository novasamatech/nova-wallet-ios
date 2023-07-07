import Foundation
import SoraFoundation
import BigInt

class StartStakingInfoBasePresenter: StartStakingInfoInteractorOutputProtocol, StartStakingInfoPresenterProtocol {
    weak var view: StartStakingInfoViewProtocol?
    let wireframe: StartStakingInfoWireframeProtocol
    let baseInteractor: StartStakingInfoInteractorInputProtocol
    let startStakingViewModelFactory: StartStakingViewModelFactoryProtocol
    let dashboardItem: Multistaking.DashboardItem

    private(set) var assetBalance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var chainAsset: ChainAsset?

    init(
        interactor: StartStakingInfoInteractorInputProtocol,
        dashboardItem: Multistaking.DashboardItem,
        wireframe: StartStakingInfoWireframeProtocol,
        startStakingViewModelFactory: StartStakingViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        baseInteractor = interactor
        self.dashboardItem = dashboardItem
        self.wireframe = wireframe
        self.startStakingViewModelFactory = startStakingViewModelFactory
        self.localizationManager = localizationManager
    }

    func provideBalanceModel() {
        guard let chainAsset = chainAsset else {
            return
        }
        let viewModel = startStakingViewModelFactory.balance(
            amount: assetBalance?.freeInPlank,
            priceData: price,
            chainAsset: chainAsset,
            locale: selectedLocale
        )
        view?.didReceive(balance: viewModel)
    }

    // MARK: - StartStakingInfoInteractorOutputProtocol

    func didReceive(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
        provideBalanceModel()
    }

    func didReceive(account _: MetaChainAccountResponse?) {}

    func didReceive(price: PriceData?) {
        self.price = price
        provideBalanceModel()
    }

    func didReceive(assetBalance: AssetBalance) {
        self.assetBalance = assetBalance
        provideBalanceModel()
    }

    func didReceive(baseError error: BaseStartStakingInfoError) {
        switch error {
        case .assetBalance, .price:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.remakeSubscriptions()
            }
        }
    }

    // MARK: - StartStakingInfoPresenterProtocol

    func setup() {
        baseInteractor.setup()
    }
}

extension StartStakingInfoBasePresenter: Localizable {
    func applyLocalization() {}
}
