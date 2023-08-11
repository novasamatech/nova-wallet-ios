import Foundation
import SoraFoundation

struct StakingSelectPoolViewFactory {
    static func createView(state: RelaychainStartStakingStateProtocol) -> StakingSelectPoolViewProtocol? {
        let chainId = state.chainAsset.chain.chainId
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let activePoolService = state.activePoolsService else {
            return nil
        }

        let queue = OperationQueue()

        let poolsOperationFactory = NominationPoolsOperationFactory(operationQueue: queue)
        let rewardCalculationFactory = NPoolsRewardEngineFactory(operationFactory: poolsOperationFactory)

        let interactor = StakingSelectPoolInteractor(
            poolsOperationFactory: poolsOperationFactory,
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory,
            rewardEngineOperationFactory: rewardCalculationFactory,
            eraPoolsService: activePoolService,
            validatorRewardService: state.relaychainRewardCalculatorService,
            connection: connection,
            runtimeService: runtimeService,
            chainAsset: state.chainAsset,
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
