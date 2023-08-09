import Foundation
import SoraFoundation

protocol StakingTypeDelegate: AnyObject {
    func changeStakingType(method: StakingSelectionMethod)
}

enum StakingTypeViewFactory {
    static func createView(
        state: RelaychainStartStakingStateProtocol,
        method: StakingSelectionMethod,
        delegate: StakingTypeDelegate?
    ) -> StakingTypeViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        guard let interactor = createInteractor(state: state, method: method) else {
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
            initialMethod: method,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            delegate: delegate
        )

        let view = StakingTypeViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        state: RelaychainStartStakingStateProtocol,
        method: StakingSelectionMethod
    ) -> StakingTypeInteractor? {
        let request = state.chainAsset.chain.accountRequest()
        let queue = OperationManagerFacade.sharedDefaultQueue
        guard let selectedAccount = SelectedWalletSettings.shared.value?.fetch(for: request) else {
            return nil
        }

        let recommendationFactory = StakingRecommendationMediatorFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: queue
        )

        guard
            let directStakingRestrictionsBuilder = recommendationFactory.createDirectStakingRestrictionsBuilder(for: state),
            let nominationPoolsRestrictionsBuilder = recommendationFactory.createPoolStakingRestrictionsBuilder(for: state),
            let directStakingRecommendationMediator = recommendationFactory.createDirectStakingMediator(for: state),
            let nominationPoolRecommendationMediator = recommendationFactory.createPoolStakingMediator(for: state)
        else {
            return nil
        }

        let interactor = StakingTypeInteractor(
            selectedAccount: selectedAccount,
            chainAsset: state.chainAsset,
            stakingSelectionMethod: method,
            directStakingRestrictionsBuilder: directStakingRestrictionsBuilder,
            nominationPoolsRestrictionsBuilder: nominationPoolsRestrictionsBuilder,
            directStakingRecommendationMediator: directStakingRecommendationMediator,
            nominationPoolRecommendationMediator: nominationPoolRecommendationMediator,
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
