import Foundation
import Foundation_iOS
import Operation_iOS

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
            currency: currencyManager.selectedCurrency,
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
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
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
        let earnServices = state.earnServices
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let presetFactory = SubtensorValidatorPresetFactory(
            directoryService: earnServices.validatorDirectoryService,
            recommendationService: earnServices.recommendationService,
            yieldService: earnServices.yieldService,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        return SubtensorSubnetDetailsInteractor(
            subnet: input.subnet.ref,
            chainAsset: state.stakingOption.chainAsset,
            priceHistoryService: earnServices.priceHistoryService,
            parametersFactory: createParametersFactory(state: state, operationQueue: operationQueue),
            presetFactory: presetFactory,
            yieldService: earnServices.yieldService,
            subnetLogosProvider: earnServices.subnetLogosProvider,
            positionsSyncService: state.positionsSyncService,
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
        let chainId = state.stakingOption.chainAsset.chain.chainId
        let timeline = SubtensorParametersTimeline(
            chainId: chainId, chainRegistry: state.chainRegistry
        )
        return SubtensorSubnetParametersFactory(
            apiFactory: state.apiOperationFactory,
            runtimeConnectionStore: ChainRegistryRuntimeConnectionStore(
                chainId: chainId, chainRegistry: state.chainRegistry
            ),
            timeline: timeline, operationQueue: operationQueue, logger: state.logger
        )
    }
}

private struct SubtensorParametersTimeline: ChainTimelineFacadeProtocol {
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    var timelineChainId: ChainModel.Id { chainRegistry.getChain(for: chainId)?.timelineChain ?? chainId }

    func createBlockTimeOperation() -> CompoundOperationWrapper<BlockTime> {
        do {
            let chain = try chainRegistry.getChainOrError(for: timelineChainId)
            let runtime = try chainRegistry.getRuntimeProviderOrError(for: timelineChainId)

            // Approximate age needs the expected duration, without a subscription-backed estimator.
            return BlockTimeOperationFactory(chain: chain).createExpectedBlockTimeWrapper(from: runtime)
        } catch {
            return .createWithError(error)
        }
    }
}
