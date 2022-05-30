import Foundation
import SoraFoundation
import SubstrateSdk
import RobinHood

struct ParaStkSelectCollatorsViewFactory {
    static func createView(
        with state: ParachainStakingSharedState,
        delegate: ParaStkSelectCollatorsDelegate
    ) -> ParaStkSelectCollatorsViewProtocol? {
        guard
            let interactor = createInteractor(for: state),
            let chainAsset = state.settings.value else {
            return nil
        }

        let wireframe = ParaStkSelectCollatorsWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo
        )

        let localizationManager = LocalizationManager.shared

        let presenter = ParaStkSelectCollatorsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegate: delegate,
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ParaStkSelectCollatorsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: ParachainStakingSharedState
    ) -> ParaStkSelectCollatorsInteractor? {
        guard
            let chainAsset = state.settings.value,
            let collatorService = state.collatorService,
            let rewardEngineService = state.rewardCalculationService else {
            return nil
        }

        let chain = chainAsset.chain

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)

        let collatorOperationFactory = ParaStkCollatorsOperationFactory(
            requestFactory: requestFactory,
            identityOperationFactory: identityOperationFactory
        )

        return ParaStkSelectCollatorsInteractor(
            chainAsset: chainAsset,
            collatorService: collatorService,
            rewardService: rewardEngineService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            collatorOperationFactory: collatorOperationFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            operationQueue: operationQueue
        )
    }
}
