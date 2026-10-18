import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorSubnetParametersFactoryProtocol {
    func createWrapper(for ref: SubtensorSubnetRef) -> CompoundOperationWrapper<SubtensorSubnetParameters>
}

final class SubtensorSubnetParametersFactory {
    let apiFactory: SubtensorApiOperationFactoryProtocol
    let runtimeConnectionStore: RuntimeConnectionStoring
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol
    private let requestFactory: StorageRequestFactoryProtocol

    init(
        apiFactory: SubtensorApiOperationFactoryProtocol,
        runtimeConnectionStore: RuntimeConnectionStoring,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.apiFactory = apiFactory
        self.runtimeConnectionStore = runtimeConnectionStore
        self.blockTimeOperationFactory = blockTimeOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
        requestFactory = StorageRequestFactory.createDefault(with: operationQueue)
    }
}

extension SubtensorSubnetParametersFactory: SubtensorSubnetParametersFactoryProtocol {
    func createWrapper(for ref: SubtensorSubnetRef) -> CompoundOperationWrapper<SubtensorSubnetParameters> {
        let hash = apiFactory.createBestBlockHashWrapper()
        let wrapper = OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let blockHash = try hash.targetOperation.extractNoCancellableResultData()
            return try self.createSnapshot(for: ref, at: blockHash)
        }
        wrapper.addDependency(wrapper: hash)
        return wrapper.insertingHead(operations: hash.allOperations)
    }
}

private extension SubtensorSubnetParametersFactory {
    func value<T>(from operation: BaseOperation<T>, field: String) -> T? {
        do {
            return try operation.extractNoCancellableResultData()
        } catch {
            logger.warning("Subtensor parameter \(field) unavailable: \(error)")
            return nil
        }
    }

    func createSnapshot(
        for ref: SubtensorSubnetRef,
        at hash: BlockHash
    ) throws -> CompoundOperationWrapper<SubtensorSubnetParameters> {
        let engine = try runtimeConnectionStore.getConnection()
        let runtime = try runtimeConnectionStore.getRuntimeProvider()
        let coder = runtime.fetchCoderFactoryOperation()
        let factory = { try coder.extractNoCancellableResultData() }
        let blockHash = try Data(hexString: hash)
        let netuid = { [StringScaleMapper(value: ref.netuid)] }
        let dynamic = apiFactory.createAllDynamicInfoWrapper(at: hash)
        let number: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BlockNumber>>> =
            requestFactory.queryItem(
                engine: engine, factory: factory, storagePath: SystemPallet.blockNumberPath, at: blockHash
            )
        let permits: CompoundOperationWrapper<[StorageResponse<[Bool]>]> = requestFactory.queryItems(
            engine: engine, keyParams: netuid, factory: factory,
            storagePath: SubtensorStakingPallet.validatorPermitPath, at: blockHash
        )
        let enabled: CompoundOperationWrapper<[StorageResponse<Bool>]> = requestFactory.queryItems(
            engine: engine, keyParams: netuid, factory: factory,
            storagePath: SubtensorStakingPallet.subnetEmissionEnabledPath, at: blockHash
        )
        let reads = number.allOperations + permits.allOperations + enabled.allOperations
        reads.forEach { $0.addDependency(coder) }
        let time = blockTimeOperationFactory.createExpectedBlockTimeWrapper(from: runtime)
        let merge = ClosureOperation<SubtensorSubnetParameters> {
            SubtensorSubnetParameters(
                ref: ref,
                rows: self.value(from: dynamic.targetOperation, field: "emission share"),
                blockNumber: self.value(from: number.targetOperation, field: "block")?.value?.value,
                permits: self.value(from: permits.targetOperation, field: "permits")?.first?.value,
                emissionEnabled: self.value(from: enabled.targetOperation, field: "emission")?.first?.value,
                blockTime: self.value(from: time.targetOperation, field: "block time")
            )
        }
        let dependencies = [coder] + dynamic.allOperations + reads + time.allOperations
        dependencies.forEach { merge.addDependency($0) }
        return CompoundOperationWrapper(targetOperation: merge, dependencies: dependencies)
    }
}
