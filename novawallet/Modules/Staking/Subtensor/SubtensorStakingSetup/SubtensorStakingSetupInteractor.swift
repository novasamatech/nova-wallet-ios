import Operation_iOS
import SubstrateSdk
import UIKit

final class SubtensorStakingSetupInteractor: SubtensorStakingBaseInteractor {
    var presenter: SubtensorSetupInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let presetFactory: SubtensorValidatorPresetFactoryProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let recommendationService: SubtensorRecommendationServiceProtocol
    let maxApyProvider: SubtensorMaxApyProviderProtocol
    let subnetsService: SubtensorSubnetsServiceProtocol
    let earnSettings: SubtensorEarnSettingsProtocol
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol

    private let quickPickCallStore = CancellableCallStore()
    private let validatorCallStore = CancellableCallStore()
    private let yieldsCallStore = CancellableCallStore()
    private let rankingCallStore = CancellableCallStore()
    private let subnetCallStore = CancellableCallStore()

    init(
        flowServices: SubtensorFlowServices,
        state: SubtensorStakingSharedStateProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol,
        logger: LoggerProtocol
    ) {
        presetFactory = state.earnServices.validatorPresetFactory
        yieldService = state.earnServices.yieldService
        recommendationService = state.earnServices.recommendationService
        maxApyProvider = state.earnServices.maxApyProvider
        subnetsService = state.subnetsService
        earnSettings = state.earnServices.earnSettings
        self.blockTimeOperationFactory = blockTimeOperationFactory

        super.init(flowServices: flowServices, state: state, logger: logger)
    }

    deinit {
        quickPickCallStore.cancel()
        validatorCallStore.cancel()
        yieldsCallStore.cancel()
        rankingCallStore.cancel()
        subnetCallStore.cancel()
    }
}

private extension SubtensorStakingSetupInteractor {
    func provideValidator(
        using wrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?>,
        subnet: SubtensorSubnetRef
    ) {
        validatorCallStore.cancel()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: validatorCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(validator):
                self?.presenter?.didReceiveValidator(validator, on: subnet)
            case let .failure(error):
                self?.logger.error("Subtensor validator preset failed: \(error)")
                self?.presenter?.didFailValidator(error, on: subnet)
            }
        }
    }
}

extension SubtensorStakingSetupInteractor: SubtensorSetupInteractorInputProtocol {
    func cancelQuickPickSnapshot() { quickPickCallStore.cancel() }

    func loadBlockTime() {
        execute(
            wrapper: blockTimeOperationFactory.createExpectedBlockTimeWrapper(from: runtimeProvider),
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(blockTime):
                self?.presenter?.didReceiveBlockTime(blockTime)
            case let .failure(error):
                self?.logger.error("Block time fetch failed: \(error)")
            }
        }
    }

    func loadQuickPickSnapshot(for order: SubtensorQuickPickOrder) {
        quickPickCallStore.cancel()
        let catalogueWrapper = catalogueService.createCatalogueWrapper()
        let infoWrapper = subnetsService.createSubnetsInfoWrapper()
        let apyWrapper = order == .apy ? maxApyProvider.createMaxApyWrapper() : .createWithResult([:])
        let mergeOperation = ClosureOperation<SubtensorQuickPickSnapshot> {
            SubtensorQuickPickSnapshot(
                catalogue: try catalogueWrapper.targetOperation.extractNoCancellableResultData(),
                info: try infoWrapper.targetOperation.extractNoCancellableResultData(),
                apy: try apyWrapper.targetOperation.extractNoCancellableResultData()
            )
        }
        mergeOperation.addDependency(catalogueWrapper.targetOperation)
        mergeOperation.addDependency(infoWrapper.targetOperation)
        mergeOperation.addDependency(apyWrapper.targetOperation)
        executeCancellable(
            wrapper: CompoundOperationWrapper(
                targetOperation: mergeOperation,
                dependencies: catalogueWrapper.allOperations + infoWrapper.allOperations + apyWrapper.allOperations
            ),
            inOperationQueue: operationQueue,
            backingCallIn: quickPickCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.warning("Subtensor quick pick snapshot unavailable for the setup: \(error)")
            }

            self?.presenter?.didReceiveQuickPickSnapshot(result)
        }
    }

    func cachedRankingView() -> HTTPCachePeek<SubtensorRankedSubnets> {
        recommendationService.cachedRankedSubnets()
    }

    func cachedYields(netuid: UInt16) -> HTTPCachePeek<SubtensorAlphaYields> {
        yieldService.cachedAlphaYields(for: netuid)
    }

    func presetValidator(on subnet: SubtensorSubnetRef, existingHotkey: AccountId?) {
        let wrapper = presetFactory.createPresetWrapper(for: subnet, existingHotkey: existingHotkey)

        provideValidator(using: wrapper, subnet: subnet)
    }

    func loadLockedValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef) {
        let wrapper = presetFactory.createLockedWrapper(for: hotkey, subnet: subnet)

        provideValidator(using: wrapper, subnet: subnet)
    }

    func loadSubnet(netuid: UInt16) {
        subnetCallStore.cancel()

        executeCancellable(
            wrapper: subnetsService.createSubnetsInfoWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: subnetCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(info):
                guard
                    let subnet = info.subnets.first(where: { $0.netuid == netuid }),
                    let price = info.prices[netuid] else {
                    self?.presenter?.didFailSubnet(SubtensorStakingSetupError.subnetUnavailable(netuid))
                    return
                }

                self?.presenter?.didReceiveSubnet(.subnet(info: subnet, price: price))
            case let .failure(error):
                self?.presenter?.didFailSubnet(error)
            }
        }
    }

    func loadYields(netuid: UInt16) {
        yieldsCallStore.cancel()

        executeCancellable(
            wrapper: yieldService.createAlphaYieldsWrapper(for: netuid),
            inOperationQueue: operationQueue,
            backingCallIn: yieldsCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(yields):
                self?.presenter?.didReceiveYields(yields, netuid: netuid)
            case let .failure(error):
                self?.logger.warning("Subtensor subnet yields unavailable for the setup: \(error)")
                self?.presenter?.didReceiveYields(nil, netuid: netuid)
            }
        }
    }

    func loadRankingView() {
        rankingCallStore.cancel()

        executeCancellable(
            wrapper: recommendationService.createRankedSubnetsWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: rankingCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(rankingView):
                self?.presenter?.didReceiveRankingView(rankingView)
            case .failure(BittensorApiError.generationStale):
                self?.presenter?.didReceiveRankingView(self?.recommendationService.cachedRankedSubnets().value)
            case let .failure(error):
                self?.logger.warning("Subtensor ranking view unavailable for the setup: \(error)")
                self?.presenter?.didReceiveRankingView(nil)
            }
        }
    }

    func saveSlippage(_ tolerance: BigRational) {
        earnSettings.slippageTolerance = tolerance
    }
}

enum SubtensorStakingSetupError: Error {
    case subnetUnavailable(UInt16)
}
