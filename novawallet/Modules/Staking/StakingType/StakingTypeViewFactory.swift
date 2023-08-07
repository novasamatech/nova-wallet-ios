import Foundation
import SoraFoundation

struct StakingTypeViewFactory {
    static func createView(state: RelaychainStartStakingStateProtocol, method _: StakingSelectionMethod) -> StakingTypeViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        guard let interactor = createInteractor(state: state) else {
            return nil
        }

        let wireframe = StakingTypeWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: state.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModelFactory = StakingTypeViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            countFormatter: NumberFormatter.quantity.localizableResource()
        )

        let presenter = StakingTypePresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: state.chainAsset,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = StakingTypeViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        state: RelaychainStartStakingStateProtocol
    ) -> StakingTypeInteractor? {
        let request = state.chainAsset.chain.accountRequest()
        let chainId = state.chainAsset.chain.chainId

        guard let selectedAccount = SelectedWalletSettings.shared.value?.fetch(for: request) else {
            return nil
        }

        guard let directStakingRestrictionsBuilder =
            createDirectStakingRestrictionsBuilder(for: state, operationQueue: OperationManagerFacade.sharedDefaultQueue) else {
            return nil
        }

        let nominationPoolsRestrictionsBuilder = PoolStakingRestrictionsBuilder(
            chainAsset: state.chainAsset,
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory
        )

        let interactor = StakingTypeInteractor(
            selectedAccount: selectedAccount,
            chainAsset: state.chainAsset,
            directStakingRestrictionsBuilder: directStakingRestrictionsBuilder,
            nominationPoolsRestrictionsBuilder: nominationPoolsRestrictionsBuilder,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared
        )

        return interactor
    }

    private static func createPoolStakingRestrictionsBuilder(
        for state: RelaychainStartStakingStateProtocol
    ) -> PoolStakingRestrictionsBuilder {
        PoolStakingRestrictionsBuilder(
            chainAsset: state.chainAsset,
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory
        )
    }

    private static func createDirectStakingRestrictionsBuilder(
        for state: RelaychainStartStakingStateProtocol,
        operationQueue: OperationQueue
    ) -> DirectStakingRestrictionsBuilder? {
        let networkInfoFactory = state.createNetworkInfoOperationFactory(for: operationQueue)

        let chainId = state.chainAsset.chain.chainId

        guard let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId) else {
            return nil
        }

        return DirectStakingRestrictionsBuilder(
            chainAsset: state.chainAsset,
            stakingLocalSubscriptionFactory: state.relaychainLocalSubscriptionFactory,
            networkInfoFactory: networkInfoFactory,
            eraValidatorService: state.eraValidatorService,
            runtimeService: runtimeService,
            operationQueue: operationQueue
        )
    }
}
