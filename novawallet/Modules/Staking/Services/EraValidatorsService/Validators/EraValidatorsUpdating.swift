import Foundation
import SubstrateSdk

struct EraValidatorResultItem {
    let validator: AccountId
    let exposure: ValidatorExposure
}

protocol EraValidatorsUpdating: AnyObject {
    func fetchValidators(
        for era: EraIndex,
        runningIn completionQueue: DispatchQueue,
        completion closure: @escaping ([EraValidatorResultItem]) -> Void
    )

    func cancel()
}

final class EraValidatorsUpdater {
    private var legacySyncService: StorageListSyncService<
        StringScaleMapper<EraIndex>, EraStakersRemoteKey, ValidatorExposure
    >?

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

    private func syncLegacyValidators(
        for era: EraIndex,
        runningIn queue: DispatchQueue,
        completion closure: @escaping ([EraValidatorResultItem]) -> Void
    ) {
        legacySyncService?.throttle()

        legacySyncService = StorageListSyncService(
            key: StringScaleMapper(value: era),
            chainId: chainId,
            storagePath: .erasStakers,
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
        legacySyncService?.throttle()
        legacySyncService = nil
    }
}

extension EraValidatorsUpdater: EraValidatorsUpdating {
    func fetchValidators(
        for era: EraIndex,
        runningIn queue: DispatchQueue,
        completion closure: @escaping ([EraValidatorResultItem]) -> Void
    ) {
        syncLegacyValidators(for: era, runningIn: queue, completion: closure)
    }

    func cancel() {
        cancelAndClear()
    }
}
