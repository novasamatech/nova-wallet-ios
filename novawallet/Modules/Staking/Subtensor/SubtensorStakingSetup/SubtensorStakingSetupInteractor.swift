import Operation_iOS
import SubstrateSdk
import UIKit

final class SubtensorStakingSetupInteractor: SubtensorStakingBaseInteractor {
    var presenter: SubtensorStakingSetupInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorStakingSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let presetFactory: SubtensorValidatorPresetFactoryProtocol
    let yieldOperationFactory: SubtensorYieldOperationFactoryProtocol
    let recommendationOperationFactory: SubtensorRecommendationOperationFactoryProtocol
    let maxApyOperationFactory: SubtensorMaxApyOperationFactoryProtocol
    let subnetsOperationFactory: SubtensorSubnetsOperationFactoryProtocol
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
        yieldOperationFactory = state.earnServices.yieldOperationFactory
        recommendationOperationFactory = state.earnServices.recommendationOperationFactory
        maxApyOperationFactory = state.earnServices.maxApyOperationFactory
        subnetsOperationFactory = state.subnetsOperationFactory
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
    func loadRemoteRankingView(keepingExpiredSeed: Bool) {
        let recommendationOperationFactory = recommendationOperationFactory
        let rankingWrapper = recommendationOperationFactory.createRankedSubnetsWrapper()

        let resolveOperation = ClosureOperation<SubtensorRankedSubnets?> {
            do {
                return try rankingWrapper.targetOperation.extractNoCancellableResultData()
            } catch BittensorApiError.generationStale {
                return recommendationOperationFactory.cachedRankedSubnets().value
            }
        }

        resolveOperation.addDependency(rankingWrapper.targetOperation)

        executeCancellable(
            wrapper: rankingWrapper.insertingTail(operation: resolveOperation),
            inOperationQueue: operationQueue,
            backingCallIn: rankingCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(rankingView):
                if rankingView != nil || !keepingExpiredSeed {
                    self?.presenter?.didReceiveRankingView(rankingView)
                }
            case let .failure(error):
                self?.logger.warning("Subtensor ranking view unavailable for the setup: \(error)")

                if !keepingExpiredSeed {
                    self?.presenter?.didReceiveRankingView(nil)
                }
            }
        }
    }

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

extension SubtensorStakingSetupInteractor: SubtensorStakingSetupInteractorInputProtocol {
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

    func loadQuickPickSnapshot(for order: SubtensorQuickPickOrder, selectedRef: SubtensorSubnetRef?) {
        quickPickCallStore.cancel()
        let catalogueWrapper = catalogueOperationFactory.createCatalogueWrapper()
        let apyWrapper = order == .apy ? maxApyOperationFactory.createMaxApyWrapper() : .createWithResult([:])
        let subnetsOperationFactory = subnetsOperationFactory
        let snapshotWrapper: CompoundOperationWrapper<SubtensorQuickPickSnapshot> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let catalogue = try catalogueWrapper.targetOperation.extractNoCancellableResultData()
                let apy = try apyWrapper.targetOperation.extractNoCancellableResultData()
                let ref = try selectedRef ?? SubtensorQuickPickVisit.select(order: order, from: catalogue, apy: apy)

                return subnetsOperationFactory.createSubnetInfoWrapper(for: ref.netuid).mapped {
                    SubtensorQuickPickSnapshot(ref: ref, info: $0)
                }
            }
        snapshotWrapper.addDependency(wrapper: catalogueWrapper)
        snapshotWrapper.addDependency(wrapper: apyWrapper)
        executeCancellable(
            wrapper: snapshotWrapper.insertingHead(
                operations: catalogueWrapper.allOperations + apyWrapper.allOperations
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
            wrapper: subnetsOperationFactory.createSubnetInfoWrapper(for: netuid),
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

        let yieldOperationFactory = yieldOperationFactory

        load(
            yieldOperationFactory.createAlphaYieldsWrapper(for: netuid),
            cached: { yieldOperationFactory.cachedFreshAlphaYields(for: netuid) },
            in: yieldsCallStore,
            label: "setup yields on netuid \(netuid)",
            deliver: { [weak self] in
                self?.presenter?.didReceiveYields($0, netuid: netuid)
            }
        )
    }

    func loadRankingView() {
        rankingCallStore.cancel()

        let recommendationOperationFactory = recommendationOperationFactory

        loadCached({
            recommendationOperationFactory.cachedRankedSubnets()
        }, in: rankingCallStore, then: { [weak self] cached in
            if let rankingView = cached.value {
                self?.presenter?.didReceiveRankingView(rankingView)
            }

            self?.loadRemoteRankingView(keepingExpiredSeed: !cached.isFresh && cached.value != nil)
        })
    }

    func saveSlippage(_ tolerance: BigRational) {
        earnSettings.slippageTolerance = tolerance
    }
}

enum SubtensorStakingSetupError: Error {
    case subnetUnavailable(UInt16)
}
