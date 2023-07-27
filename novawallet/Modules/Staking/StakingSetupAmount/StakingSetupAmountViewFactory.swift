import Foundation
import SoraFoundation

struct StakingSetupAmountViewFactory {
    static func createView(chainAsset: ChainAsset) -> StakingSetupAmountViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        let selectedWalletSettings = SelectedWalletSettings.shared
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationQueue = OperationQueue()
        let interactor = StakingSetupAmountInteractor(
            selectedWalletSettings: selectedWalletSettings,
            selectedChainAsset: chainAsset,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
        let wireframe = StakingSetupAmountWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let viewModelFactory = StakingAmountViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            estimatedEarningsFormatter: NumberFormatter.percentBase.localizableResource()
        )
        let chainAssetViewModelFactory = ChainAssetViewModelFactory(networkViewModelFactory: NetworkViewModelFactory())

        let presenter = StakingSetupAmountPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = StakingSetupAmountViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
