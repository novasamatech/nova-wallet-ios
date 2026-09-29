import Foundation
import Foundation_iOS
import Operation_iOS
import SubstrateSdk
import UIKit_iOS

enum SubtensorOperationResultViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        request: SubtensorOperationResultRequest,
        delegate: SubtensorOperationResultDelegate
    ) -> ControllerBackedProtocol? {
        let chain = state.stakingOption.chainAsset.chain

        guard
            let services = SubtensorFlowServicesFactory.createServices(for: state),
            services.isFlowAccount(request.account),
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        guard let operationService = try? state.createStakingOperationService(
            for: services.account.chainAccount.accountId,
            extrinsicService: services.extrinsicService,
            extrinsicSubmitMonitor: services.extrinsicSubmitMonitor,
            signer: services.signer
        ) else {
            return nil
        }

        let interactor = createInteractor(
            for: state,
            request: request,
            operationService: operationService,
            connection: connection,
            services: services
        )

        let presenter = SubtensorOperationResultPresenter(
            request: request,
            stakingOption: state.stakingOption,
            interactor: interactor,
            wireframe: SubtensorOperationResultWireframe(state: state),
            viewModelFactory: SubtensorOperationResultViewModelFactory(
                chainAsset: state.stakingOption.chainAsset,
                priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
            ),
            localizationManager: LocalizationManager.shared
        )

        let view = createPresentedView(for: request, presenter: presenter)

        presenter.view = view
        presenter.delegate = delegate
        interactor.presenter = presenter

        return view
    }
}

private extension SubtensorOperationResultViewFactory {
    static func createInteractor(
        for state: SubtensorStakingSharedStateProtocol,
        request: SubtensorOperationResultRequest,
        operationService: SubtensorStakingOperationServiceProtocol,
        connection: JSONRPCEngine,
        services: SubtensorFlowServices
    ) -> SubtensorOperationResultInteractor {
        let operationQueue = services.operationQueue

        let chainFactory = SubtensorResultChainFactory(
            chain: state.stakingOption.chainAsset.chain,
            connection: connection,
            runtimeProvider: services.runtimeProvider,
            rootHoldFactory: state.earnServices.rootHoldFactory,
            blockNumberOperationFactory: BlockNumberOperationFactory(
                chainRegistry: state.chainRegistry,
                operationQueue: operationQueue
            ),
            storageRequestFactory: StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: OperationManager(operationQueue: operationQueue)
            )
        )

        return SubtensorOperationResultInteractor(
            operation: request.operation,
            coldkey: request.account.chainAccount.accountId,
            loadsSubnetData: !request.target.isRoot,
            operationService: operationService,
            chainFactory: chainFactory,
            catalogueService: state.earnServices.catalogueService,
            earnConfigProvider: state.earnServices.earnConfigProvider,
            positionsSyncService: services.positionsSyncService,
            osMediator: OperatingSystemMediator(),
            applicationHandler: ApplicationHandler(),
            schedulerFactory: { Scheduler(with: $0, callbackQueue: .main) },
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }

    static func createPresentedView(
        for request: SubtensorOperationResultRequest,
        presenter: SubtensorOperationResultPresenter
    ) -> SubtensorResultViewProtocol {
        guard request.target.isRoot else {
            let view = SubtensorOperationResultViewController(
                presenter: presenter,
                localizationManager: LocalizationManager.shared
            )

            view.modalPresentationStyle = .fullScreen

            return view
        }

        let view = SubtensorResultSheetViewController(presenter: presenter)

        view.modalTransitioningFactory = ModalSheetPresentationFactory(configuration: .subtensorResultSheet)
        view.modalPresentationStyle = .custom

        return view
    }
}
