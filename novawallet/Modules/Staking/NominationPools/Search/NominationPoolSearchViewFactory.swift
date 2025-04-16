import Foundation
import Foundation_iOS

struct NominationPoolSearchViewFactory {
    static func createView(
        state: RelaychainStartStakingStateProtocol,
        delegate: StakingSelectPoolDelegate,
        selectedPoolId: NominationPools.PoolId?
    ) -> NominationPoolSearchViewProtocol? {
        guard
            let interactor = createInteractor(for: state),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = NominationPoolSearchWireframe()

        let viewModelFactory = StakingSelectPoolViewModelFactory(
            apyFormatter: NumberFormatter.percentAPY.localizableResource(),
            membersFormatter: NumberFormatter.quantity.localizableResource(),
            poolIconFactory: NominationPoolsIconFactory()
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: state.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let dataValidatingFactory = NominationPoolDataValidatorFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = NominationPoolSearchPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedPoolId: selectedPoolId,
            dataValidatingFactory: dataValidatingFactory,
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
        dataValidatingFactory.view = view

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
