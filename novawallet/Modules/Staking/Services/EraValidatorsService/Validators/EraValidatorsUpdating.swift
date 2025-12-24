import Foundation
import SubstrateSdk
import Operation_iOS

struct EraValidatorResultItem {
    let validator: AccountId
    let exposure: Staking.ValidatorExposure
}

protocol EraValidatorsUpdating: AnyObject {
    func fetchValidators(
        for era: Staking.EraIndex,
        runningIn completionQueue: DispatchQueue,
        completion closure: @escaping ([EraValidatorResultItem]) -> Void
    )

    func cancel()
}

final class EraValidatorsUpdater {
    private var legacySyncService: StorageListSyncService<
        StringScaleMapper<Staking.EraIndex>, EraStakersRemoteKey, Staking.ValidatorExposure
    >?

    private var overviewSyncService: StorageListSyncService<
        StringScaleMapper<Staking.EraIndex>, EraStakersRemoteKey, Staking.ValidatorOverview
    >?

    private var exposureSyncService: StorageListSyncService<
        StringScaleMapper<Staking.EraIndex>, EraStakersPagedRemoteKey, Staking.ValidatorExposurePage
    >?

    private var callableStore = CancellableCallStore()

    let chainId: ChainModel.Id
    let substrateRepositoryFactory: SubstrateRepositoryFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chainId: ChainModel.Id,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        substrateRepositoryFactory: SubstrateRepositoryFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainId = chainId
        self.connection = connection
        self.runtimeService = runtimeService
        self.substrateRepositoryFactory = substrateRepositoryFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        cancelAndClear()
    }

    private func mergeOverviewAndExposures(
        _ overview: [AccountId: Staking.ValidatorOverview],
        exposures: [StorageListSyncResult<EraStakersPagedRemoteKey, Staking.ValidatorExposurePage>.Item],
        completion closure: @escaping ([EraValidatorResultItem]) -> Void
    ) {
        let indexedIndividualExposures: [AccountId: [Staking.IndividualExposure]] = exposures.reduce(
            into: [:]
        ) { accum, item in
            let validator = item.key.validator

            if let individualExposures = accum[validator] {
                accum[validator] = individualExposures + item.value.others
            } else {
                accum[validator] = item.value.others
            }
        }

        let indexedExposures = overview.reduce(into: [AccountId: Staking.ValidatorExposure]()) { accum, keyValue in
            let validator = keyValue.key

            let others = indexedIndividualExposures[validator] ?? []
            accum[validator] = Staking.ValidatorExposure(
                total: keyValue.value.total,
                own: keyValue.value.own,
                others: others
            )
        }

        let result = indexedExposures.map { EraValidatorResultItem(validator: $0.key, exposure: $0.value) }
        closure(result)
    }

    private func syncValidatorsExposure(
        for era: Staking.EraIndex,
        overview: [AccountId: Staking.ValidatorOverview],
        runningIn queue: DispatchQueue,
        completion closure: @escaping ([EraValidatorResultItem]) -> Void
    ) {
        exposureSyncService = StorageListSyncService(
            key: StringScaleMapper(value: era),
            chainId: chainId,
            storagePath: Staking.eraStakersPaged,
            repositoryFactory: substrateRepositoryFactory,
            connection: connection,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue,
            logger: logger,
            completionQueue: queue
        ) { [weak self] result in
            self?.mergeOverviewAndExposures(overview, exposures: result.items, completion: closure)
        }

        exposureSyncService?.setup()
    }

    private func syncValidatorsOverview(
        for era: Staking.EraIndex,
        runningIn queue: DispatchQueue,
        completion closure: @escaping ([EraValidatorResultItem]) -> Void
    ) {
        overviewSyncService = StorageListSyncService(
            key: StringScaleMapper(value: era),
            chainId: chainId,
            storagePath: Staking.eraStakersOverview,
            repositoryFactory: substrateRepositoryFactory,
            connection: connection,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue,
            logger: logger,
            completionQueue: queue
        ) { [weak self] result in
            let overview = result.items.reduce(into: [AccountId: Staking.ValidatorOverview]()) { accum, item in
                accum[item.key.validator] = item.value
            }

            if !overview.isEmpty {
                self?.syncValidatorsExposure(
                    for: era,
                    overview: overview,
                    runningIn: queue,
                    completion: closure
                )
            } else {
                closure([])
            }
        }

        overviewSyncService?.setup()
    }

    private func syncPagedValidatorsIfNeeded(
        for era: Staking.EraIndex,
        runningIn queue: DispatchQueue,
        completion closure: @escaping ([EraValidatorResultItem]) -> Void
    ) {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        executeCancellable(
            wrapper: .init(targetOperation: codingFactoryOperation),
            inOperationQueue: operationQueue,
            backingCallIn: callableStore,
            runningCallbackIn: queue
        ) { [weak self] result in
            switch result {
            case let .success(codingFactory):
                if codingFactory.hasStorage(for: Staking.eraStakersOverview) {
                    self?.syncValidatorsOverview(for: era, runningIn: queue, completion: closure)
                } else {
                    dispatchInQueueWhenPossible(queue) {
                        closure([])
                    }
                }
            case .failure:
                self?.logger.error("Can't fetch coding factory")
            }
        }
    }

    private func syncLegacyValidators(
        for era: Staking.EraIndex,
        runningIn queue: DispatchQueue,
        completion closure: @escaping ([EraValidatorResultItem]) -> Void
    ) {
        legacySyncService?.throttle()

        legacySyncService = StorageListSyncService(
            key: StringScaleMapper(value: era),
            chainId: chainId,
            storagePath: Staking.erasStakers,
            repositoryFactory: substrateRepositoryFactory,
            connection: connection,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue,
            logger: logger,
            completionQueue: queue
        ) { result in
            let exposures = result.items.map {
                EraValidatorResultItem(validator: $0.key.validator, exposure: $0.value)
            }

            closure(exposures)
        }

        legacySyncService?.setup()
    }

    private func cancelAndClear() {
        callableStore.cancel()

        legacySyncService?.throttle()
        legacySyncService = nil

        overviewSyncService?.throttle()
        overviewSyncService = nil

        exposureSyncService?.throttle()
        exposureSyncService = nil
    }
}

extension EraValidatorsUpdater: EraValidatorsUpdating {
    func fetchValidators(
        for era: Staking.EraIndex,
        runningIn queue: DispatchQueue,
        completion closure: @escaping ([EraValidatorResultItem]) -> Void
    ) {
        syncPagedValidatorsIfNeeded(for: era, runningIn: queue) { [weak self] items in
            if !items.isEmpty {
                closure(items)
            } else {
                self?.syncLegacyValidators(for: era, runningIn: queue, completion: closure)
            }
        }
    }

    func cancel() {
        cancelAndClear()
    }
}
