import Foundation
import SoraFoundation
import BigInt
import SubstrateSdk

protocol StakingTypeDelegate: AnyObject {
    func changeStakingType(method: StakingSelectionMethod)
}

enum StakingTypeViewFactory {
    static func createView(
        state: RelaychainStartStakingStateProtocol,
        method: StakingSelectionMethod,
        amount: BigUInt,
        delegate: StakingTypeDelegate?
    ) -> StakingTypeViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        guard let interactor = createInteractor(state: state, method: method, amount: amount) else {
            return nil
        }

        let wireframe = StakingTypeWireframe(state: state)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: state.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModelFactory = StakingTypeViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            stakingViewModelFactory: SelectedStakingViewModelFactory()
        )

        let presenter = StakingTypePresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: state.chainAsset,
            amount: amount,
            canChangeType: state.stakingType == nil,
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
        method: StakingSelectionMethod,
        amount: BigUInt
    ) -> StakingTypeInteractor? {
        let request = state.chainAsset.chain.accountRequest()
        let queue = OperationManagerFacade.sharedDefaultQueue
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard let selectedAccount = SelectedWalletSettings.shared.value?.fetch(for: request) else {
            return nil
        }
        guard
            let connection = chainRegistry.getConnection(for: state.chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: state.chainAsset.chain.chainId)
        else { return nil }

        let recommendationFactory = StakingRecommendationMediatorFactory(
            chainRegistry: chainRegistry,
            operationQueue: queue
        )

        guard
            let directStakingRestrictionsBuilder = recommendationFactory.createDirectStakingRestrictionsBuilder(
                for: state
            ),
            let nominationPoolsRestrictionsBuilder = recommendationFactory.createPoolStakingRestrictionsBuilder(
                for: state
            ),
            let directStakingRecommendationMediator = recommendationFactory.createDirectStakingMediator(for: state),
            let nominationPoolRecommendationMediator = recommendationFactory.createPoolStakingMediator(for: state)
        else {
            return nil
        }

        let eraValidatorService = state.eraValidatorService
        let rewardCalculationService = state.relaychainRewardCalculatorService

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let validatorOperationFactory = ValidatorOperationFactory(
            chainInfo: state.chainAsset.chainAssetInfo,
            eraValidatorService: eraValidatorService,
            rewardService: rewardCalculationService,
            storageRequestFactory: storageRequestFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
        )

        let interactor = StakingTypeInteractor(
            selectedAccount: selectedAccount,
            chainAsset: state.chainAsset,
            amount: amount,
            stakingSelectionMethod: method,
            directStakingRestrictionsBuilder: directStakingRestrictionsBuilder,
            nominationPoolsRestrictionsBuilder: nominationPoolsRestrictionsBuilder,
            directStakingRecommendationMediator: directStakingRecommendationMediator,
            nominationPoolRecommendationMediator: nominationPoolRecommendationMediator,
            validatorOperationFactory: validatorOperationFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return interactor
    }
}
