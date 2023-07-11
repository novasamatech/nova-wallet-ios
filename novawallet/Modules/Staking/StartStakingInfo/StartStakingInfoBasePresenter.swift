import Foundation
import SoraFoundation
import BigInt

class StartStakingInfoBasePresenter: StartStakingInfoInteractorOutputProtocol, StartStakingInfoPresenterProtocol {
    weak var view: StartStakingInfoViewProtocol?
    let wireframe: StartStakingInfoWireframeProtocol
    let baseInteractor: StartStakingInfoInteractorInputProtocol
    let startStakingViewModelFactory: StartStakingViewModelFactoryProtocol

    private(set) var price: PriceData?
    private(set) var chainAsset: ChainAsset?
    private(set) var balanceState: BalanceState?

    init(
        interactor: StartStakingInfoInteractorInputProtocol,
        wireframe: StartStakingInfoWireframeProtocol,
        startStakingViewModelFactory: StartStakingViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        baseInteractor = interactor
        self.wireframe = wireframe
        self.startStakingViewModelFactory = startStakingViewModelFactory
        self.localizationManager = localizationManager
    }

    func provideBalanceModel() {
        guard let chainAsset = chainAsset else {
            return
        }
        switch balanceState {
        case let .assetBalance(balance):
            let viewModel = startStakingViewModelFactory.balance(
                amount: balance.freeInPlank,
                priceData: price,
                chainAsset: chainAsset,
                locale: selectedLocale
            )
            view?.didReceive(balance: viewModel)
        case .noAccount:
            let viewModel = startStakingViewModelFactory.noAccount(chain: chainAsset.chain, locale: selectedLocale)
            view?.didReceive(balance: viewModel)
        case .none:
            break
        }
    }

    // MARK: - StartStakingInfoInteractorOutputProtocol

    func didReceive(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
        provideBalanceModel()
    }

    func didReceive(price: PriceData?) {
        self.price = price
        provideBalanceModel()
    }

    func didReceive(assetBalance: AssetBalance) {
        balanceState = .assetBalance(assetBalance)
        provideBalanceModel()
    }

    func didReceive(accountId: AccountId?) {
        if accountId == nil {
            balanceState = .noAccount
            provideBalanceModel()
        }
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
