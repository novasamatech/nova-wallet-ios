import Foundation
import SoraFoundation
import BigInt

protocol StakingSelectPoolDelegate: AnyObject {
    func changePoolSelection(selectedPool: NominationPools.SelectedPool)
}

enum StakingSelectPoolViewFactory {
    static func createView(
        state: RelaychainStartStakingStateProtocol,
        amount: BigUInt,
        selectedPool: NominationPools.SelectedPool?,
        delegate: StakingSelectPoolDelegate?
    ) -> StakingSelectPoolViewProtocol? {
        let chainId = state.chainAsset.chain.chainId
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let activePoolService = state.activePoolsService else {
            return nil
        }
        let queue = OperationQueue()

        let recommendationFactory = StakingRecommendationMediatorFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: queue
        )
        guard let recommendationMediator = recommendationFactory.createPoolStakingMediator(for: state) else {
            return nil
        }

        let poolsOperationFactory = NominationPoolsOperationFactory(operationQueue: queue)
        let rewardCalculationFactory = NPoolsRewardEngineFactory(operationFactory: poolsOperationFactory)

        let interactor = StakingSelectPoolInteractor(
            poolsOperationFactory: poolsOperationFactory,
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory,
            rewardEngineOperationFactory: rewardCalculationFactory,
            recommendationMediator: recommendationMediator,
            eraPoolsService: activePoolService,
            validatorRewardService: state.relaychainRewardCalculatorService,
            connection: connection,
            runtimeService: runtimeService,
            chainAsset: state.chainAsset,
            amount: amount,
            operationQueue: queue
        )

        let wireframe = StakingSelectPoolWireframe()
        let viewModelFactory = StakingSelectPoolViewModelFactory(
            apyFormatter: NumberFormatter.percentAPY.localizableResource(),
            membersFormatter: NumberFormatter.quantity.localizableResource(),
            poolIconFactory: NominationPoolsIconFactory()
        )

        let presenter = StakingSelectPoolPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAsset: state.chainAsset,
            delegate: delegate,
            selectedPool: selectedPool,
            localizationManager: LocalizationManager.shared
        )

        let view = StakingSelectPoolViewController(
            presenter: presenter,
            numberFormatter: NumberFormatter.quantity.localizableResource(),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
