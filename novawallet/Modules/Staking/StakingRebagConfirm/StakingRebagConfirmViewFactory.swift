import Foundation
import SoraFoundation

struct StakingRebagConfirmViewFactory {
    static func createView(with state: StakingSharedState) -> StakingRebagConfirmViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = selectedMetaAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let networkInfoFactory = try? state.createNetworkInfoOperationFactory(for: chainAsset.chain)
        else {
            return nil
        }

        let interactor = StakingRebagConfirmInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            feeProxy: ExtrinsicFeeProxy(),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            networkInfoFactory: networkInfoFactory,
            eraValidatorService: state.eraValidatorService,
            operationManager: OperationManagerFacade.sharedManager,
            currencyManager: currencyManager
        )

        let wireframe = StakingRebagConfirmWireframe()

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = StakingRebagConfirmPresenter(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = StakingRebagConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
