import Foundation
import SoraFoundation

struct NominationPoolSearchViewFactory {
    static func createView(
        state: RelaychainStartStakingStateProtocol,
        delegate: StakingSelectPoolDelegate
    ) -> NominationPoolSearchViewProtocol? {
        guard let interactor = createInteractor(for: state) else {
            return nil
        }

        let wireframe = NominationPoolSearchWireframe()

        let viewModelFactory = StakingSelectPoolViewModelFactory(
            apyFormatter: NumberFormatter.percentAPY.localizableResource(),
            membersFormatter: NumberFormatter.quantity.localizableResource(),
            poolIconFactory: NominationPoolsIconFactory()
        )

        let presenter = NominationPoolSearchPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAsset: state.chainAsset,
            delegate: delegate,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = NominationPoolSearchViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            keyboardAppearanceStrategy: EventDrivenKeyboardStrategy(events: [.viewDidAppear])
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createInteractor(for state: RelaychainStartStakingStateProtocol) -> NominationPoolSearchInteractor? {
        let chainId = state.chainAsset.chain.chainId
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let activePoolService = state.activePoolsService else {
            return nil
        }

        let queue = OperationManagerFacade.sharedDefaultQueue
        let poolsOperationFactory = NominationPoolsOperationFactory(operationQueue: queue)
        let rewardCalculationFactory = NPoolsRewardEngineFactory(operationFactory: poolsOperationFactory)

        let interactor = NominationPoolSearchInteractor(
            chainAsset: state.chainAsset,
            poolsOperationFactory: poolsOperationFactory,
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory,
            rewardEngineOperationFactory: rewardCalculationFactory,
            eraNominationPoolsService: activePoolService,
            validatorRewardService: state.relaychainRewardCalculatorService,
            connection: connection,
            runtimeService: runtimeService,
            searchOperationFactory: NominationPoolSearchOperationFactory(),
            operationQueue: queue
        )

        return interactor
    }
}
