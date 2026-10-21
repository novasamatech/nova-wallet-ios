import Foundation
import Foundation_iOS

enum SubtensorSubnetDetailsViewFactory {
    static func createView(
        for state: SubtensorSharedStateProtocol,
        input: SubtensorSubnetDetailsInput,
        host: SubtensorSubnetDetailsHost,
        abandonTracker: AnalyticsAbandonTracker?,
        delegate: SubtensorSubnetSelectDelegate
    ) -> SubtensorSubnetDetailsViewProtocol? {
        guard
            !input.target.isRoot,
            input.target.netuid == input.subnet.netuid,
            input.target.subnetInfo?.networkRegisteredAt == input.subnet.ref.registeredAt,
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = createInteractor(for: state, input: input, currencyManager: currencyManager)

        let viewModelFactory = SubtensorSubnetDetailsViewModelFactory(
            subnet: input.subnet,
            chainAsset: state.stakingOption.chainAsset,
            currencyManager: currencyManager,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let presenter = SubtensorSubnetDetailsPresenter(
            input: input,
            host: host,
            selectionDelegate: delegate,
            interactor: interactor,
            wireframe: SubtensorSubnetDetailsWireframe(state: state),
            viewModelFactory: viewModelFactory,
            chainAsset: state.stakingOption.chainAsset,
            abandonTracker: abandonTracker,
            localizationManager: LocalizationManager.shared
        )

        let singleTapHapticPlayer = HapticPlayerFactory.createHapticPlayer(patternConfiguration: .singleTap)

        let view = SubtensorSubnetDetailsViewController(
            presenter: presenter,
            seekHapticPlayer: HapticPlayerFactory.createProgressivePlayer(patternConfiguration: .chartSeek),
            chartLongPressHapticPlayer: singleTapHapticPlayer,
            periodControlHapticPlayer: singleTapHapticPlayer,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

private extension SubtensorSubnetDetailsViewFactory {
    static func createInteractor(
        for state: SubtensorSharedStateProtocol,
        input: SubtensorSubnetDetailsInput,
        currencyManager: CurrencyManagerProtocol
    ) -> SubtensorSubnetDetailsInteractor {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        return SubtensorSubnetDetailsInteractor(
            subnet: input.subnet.ref,
            state: state,
            parametersOperationFactory: createParametersOperationFactory(state: state, operationQueue: operationQueue),
            applicationHandler: ApplicationHandler(),
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}

extension SubtensorSubnetDetailsViewFactory {
    static func createParametersOperationFactory(
        state: SubtensorSharedStateProtocol,
        operationQueue: OperationQueue
    ) -> SubtensorSubnetParametersOperationFactoryProtocol {
        let chain = state.stakingOption.chainAsset.chain
        return SubtensorSubnetParametersOperationFactory(
            apiFactory: state.apiOperationFactory,
            runtimeConnectionStore: ChainRegistryRuntimeConnectionStore(
                chainId: chain.chainId, chainRegistry: state.chainRegistry
            ),
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
            operationQueue: operationQueue, logger: state.logger
        )
    }
}
