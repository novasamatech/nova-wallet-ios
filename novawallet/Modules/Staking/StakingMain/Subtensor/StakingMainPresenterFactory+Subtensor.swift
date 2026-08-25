import Foundation
import Foundation_iOS
import Operation_iOS
import SubstrateSdk

extension StakingMainPresenterFactory {
    func createSubtensorPresenter(
        for stakingOption: Multistaking.ChainAssetOption,
        view: StakingMainViewProtocol
    ) -> SubtensorStakingDetailsPresenter? {
        guard let sharedState = try? sharedStateFactory.createSubtensorStaking(for: stakingOption) else {
            return nil
        }

        guard let interactor = createSubtensorInteractor(state: sharedState) else {
            return nil
        }

        let wireframe = SubtensorStakingDetailsWireframe(state: sharedState)

        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let priceAssetInfo = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = SubtensorStkStateViewModelFactory(priceAssetInfoFactory: priceAssetInfo)

        let presenter = SubtensorStakingDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            selectedAccount: interactor.selectedAccount,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return presenter
    }

    func createSubtensorInteractor(
        state: SubtensorStakingSharedStateProtocol
    ) -> SubtensorStakingDetailsInteractor? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        let networkInfoFactory = SubtensorNetworkInfoFactory(
            runtimeConnectionStore: ChainRegistryRuntimeConnectionStore(
                chainId: chainAsset.chain.chainId,
                chainRegistry: state.chainRegistry
            ),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let stakingRewardsLocalSubscriptionFactory = StakingRewardsLocalSubscriptionFactory(
            chainRegistry: state.chainRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManager(operationQueue: OperationManagerFacade.sharedDefaultQueue),
            logger: Logger.shared
        )

        return SubtensorStakingDetailsInteractor(
            selectedAccount: selectedAccount,
            sharedState: state,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            stakingRewardsLocalSubscriptionFactory: stakingRewardsLocalSubscriptionFactory,
            networkInfoFactory: networkInfoFactory,
            applicationHandler: ApplicationHandler(),
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
