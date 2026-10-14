import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubnetParametersFactoryProtocol {
    func createWrapper(for ref: SubtensorSubnetRef) -> CompoundOperationWrapper<SubtensorSubnetParameters>
}

final class SubtensorSubnetParametersFactory {
    let apiFactory: SubtensorApiOperationFactoryProtocol
    let runtimeConnectionStore: RuntimeConnectionStoring
    let timeline: ChainTimelineFacadeProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol
    private let queryFactory = SubtensorChunkedStorageQueryFactory(
        keysPerQuery: 1, timeout: JSONRPCTimeout.singleNode
    )

    init(
        apiFactory: SubtensorApiOperationFactoryProtocol,
        runtimeConnectionStore: RuntimeConnectionStoring,
        timeline: ChainTimelineFacadeProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.apiFactory = apiFactory
        self.runtimeConnectionStore = runtimeConnectionStore
        self.timeline = timeline
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension SubtensorSubnetParametersFactory: SubnetParametersFactoryProtocol {
    func createWrapper(for ref: SubtensorSubnetRef) -> CompoundOperationWrapper<SubtensorSubnetParameters> {
        let hash = apiFactory.createBestBlockHashWrapper()
        let wrapper = OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let blockHash = try hash.targetOperation.extractNoCancellableResultData()
            return self.createSnapshot(for: ref, at: blockHash)
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

    func createStorageRead<T: Decodable>(
        path: StorageCodingPath,
        netuid: UInt16?,
        blockHash: BlockHash
    ) -> CompoundOperationWrapper<T?> {
        do {
            let coder = try runtimeConnectionStore.getRuntimeProvider().fetchCoderFactoryOperation()
            let hash = ClosureOperation { try Data(hexString: blockHash) }
            let context = SubtensorChunkedStorageQueryFactory.Context(
                engine: try runtimeConnectionStore.getConnection(),
                codingFactoryOperation: coder,
                blockHashOperation: hash
            )
            let keys: BaseOperation<[Data]>
            if let netuid {
                keys = queryFactory.createKeysOperation(
                    path: path, params: [StringScaleMapper(value: netuid)], codingFactoryOperation: coder
                )
            } else {
                keys = try queryFactory.createPlainKeyOperation(path: path)
            }
            let read: CompoundOperationWrapper<[StorageResponse<T>]> = queryFactory.createQueryWrapper(
                path: path, keysOperation: keys, maxKeyCount: 1, context: context
            )
            let map = ClosureOperation<T?> {
                try read.targetOperation.extractNoCancellableResultData().first?.value
            }
            map.addDependency(read.targetOperation)
            return read.insertingHead(operations: [coder, hash]).insertingTail(operation: map)
        } catch {
            return .createWithError(error)
        }
    }

    func createSnapshot(
        for ref: SubtensorSubnetRef,
        at hash: BlockHash
    ) -> CompoundOperationWrapper<SubtensorSubnetParameters> {
        let dynamic = apiFactory.createAllDynamicInfoWrapper(at: hash)
        let number: CompoundOperationWrapper<StringScaleMapper<BlockNumber>?> = createStorageRead(
            path: SystemPallet.blockNumberPath, netuid: nil, blockHash: hash
        )
        let permits: CompoundOperationWrapper<[Bool]?> = createStorageRead(
            path: SubtensorStakingPallet.validatorPermitPath, netuid: ref.netuid, blockHash: hash
        )
        let enabled: CompoundOperationWrapper<Bool?> = createStorageRead(
            path: SubtensorStakingPallet.subnetEmissionEnabledPath, netuid: ref.netuid, blockHash: hash
        )
        let time = timeline.createBlockTimeOperation()
        let merge = ClosureOperation<SubtensorSubnetParameters> {
            SubtensorSubnetParameters(
                ref: ref,
                rows: self.value(from: dynamic.targetOperation, field: "emission share"),
                blockNumber: (self.value(from: number.targetOperation, field: "block") ?? nil)?.value,
                permits: self.value(from: permits.targetOperation, field: "permits") ?? nil,
                emissionEnabled: self.value(from: enabled.targetOperation, field: "emission") ?? nil,
                blockTime: self.value(from: time.targetOperation, field: "block time")
            )
        }
        let dependencies = dynamic.allOperations + number.allOperations +
            permits.allOperations + enabled.allOperations + time.allOperations
        dependencies.forEach { merge.addDependency($0) }
        return CompoundOperationWrapper(targetOperation: merge, dependencies: dependencies)
    }
}
