import Foundation
import Foundation_iOS

final class TransferNetworkSelectionPresenter {
    weak var view: TransferNetworkSelectionViewProtocol?
    let interactor: TransferNetworkSelectionInteractorInputProtocol
    let chainAssets: [ChainAsset]
    let balanceViewModeFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol

    private var balances: [ChainAssetId: AssetBalance] = [:]
    private var prices: [ChainAssetId: PriceData] = [:]

    init(
        chainAssets: [ChainAsset],
        interactor: TransferNetworkSelectionInteractorInputProtocol,
        balanceViewModeFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol
    ) {
        self.chainAssets = chainAssets
        self.interactor = interactor
        self.balanceViewModeFactoryFacade = balanceViewModeFactoryFacade
        self.networkViewModelFactory = networkViewModelFactory
    }

    private func provideViewModel() {
        let viewModels = chainAssets.map { chainAsset in

            let networkViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)
            let balanceViewModel: LocalizableResource<BalanceViewModelProtocol>?

            if let balance = balances[chainAsset.chainAssetId] {
                let decimalBalance = balance.transferable.decimal(precision: chainAsset.asset.precision)
                balanceViewModel = balanceViewModeFactoryFacade.balanceFromPrice(
                    targetAssetInfo: chainAsset.assetDisplayInfo,
                    amount: decimalBalance,
                    priceData: prices[chainAsset.chainAssetId]
                )
            } else {
                balanceViewModel = nil
            }

            return LocalizableResource { locale in
                TransferNetworkSelectionViewModel(
                    network: networkViewModel,
                    balance: balanceViewModel?.value(for: locale)
                )
            }
        }

        view?.didReceive(viewModels: viewModels)
    }
}

extension TransferNetworkSelectionPresenter: TransferNetworkSelectionPresenterProtocol {
    func setup() {
        provideViewModel()

        interactor.setup()
    }
}

extension TransferNetworkSelectionPresenter: TransferNetworkSelectionInteractorOutputProtocol {
    func didReceive(balances: [ChainAssetId: AssetBalance], prices: [ChainAssetId: PriceData]) {
        self.balances = balances
        self.prices = prices

        provideViewModel()
    }
}
