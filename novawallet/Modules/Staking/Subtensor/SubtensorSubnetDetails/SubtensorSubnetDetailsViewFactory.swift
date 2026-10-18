import Foundation
import Foundation_iOS

enum SubtensorSubnetDetailsViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        input: SubtensorSubnetDetailsInput,
        host: SubtensorSubnetDetailsHost,
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
            earnSettings: state.earnServices.earnSettings,
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
        for state: SubtensorStakingSharedStateProtocol,
        input: SubtensorSubnetDetailsInput,
        currencyManager: CurrencyManagerProtocol
    ) -> SubtensorSubnetDetailsInteractor {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        return SubtensorSubnetDetailsInteractor(
            subnet: input.subnet.ref,
            state: state,
            parametersFactory: createParametersFactory(state: state, operationQueue: operationQueue),
            applicationHandler: ApplicationHandler(),
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}

extension SubtensorSubnetDetailsViewFactory {
    static func createParametersFactory(
        state: SubtensorStakingSharedStateProtocol,
        operationQueue: OperationQueue
    ) -> SubnetParametersFactoryProtocol {
        let chain = state.stakingOption.chainAsset.chain
        return SubtensorSubnetParametersFactory(
            apiFactory: state.apiOperationFactory,
            runtimeConnectionStore: ChainRegistryRuntimeConnectionStore(
                chainId: chain.chainId, chainRegistry: state.chainRegistry
            ),
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
            operationQueue: operationQueue, logger: state.logger
        )
    }
}
