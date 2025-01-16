import Foundation
import Foundation_iOS
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
            stakingViewModelFactory: SelectedStakingTypeViewModelFactory()
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

        guard let selectedAccount = SelectedWalletSettings.shared.value?.fetch(for: request) else {
            return nil
        }

        let recommendationFactory = StakingRecommendationMediatorFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
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

        let interactor = StakingTypeInteractor(
            selectedAccount: selectedAccount,
            chainAsset: state.chainAsset,
            amount: amount,
            stakingSelectionMethod: method,
            directStakingRestrictionsBuilder: directStakingRestrictionsBuilder,
            nominationPoolsRestrictionsBuilder: nominationPoolsRestrictionsBuilder,
            directStakingRecommendationMediator: directStakingRecommendationMediator,
            nominationPoolRecommendationMediator: nominationPoolRecommendationMediator
        )

        return interactor
    }
}
