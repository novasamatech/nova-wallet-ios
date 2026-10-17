import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorRootHoldFactoryProtocol {
    func createHoldsWrapper(
        coldkey: AccountId,
        hotkeys: [AccountId]
    ) -> CompoundOperationWrapper<([AccountId: SubtensorRootHold], BlockTime)>
}

extension SubtensorRootHold {
    func remainingBlocks(at head: UInt64) -> UInt64 {
        let elapsed = head > lastStakeBlock ? head - lastStakeBlock : 0

        return elapsed >= interval ? 0 : interval - elapsed
    }
}

final class SubtensorRootHoldFactory {
    let runtimeConnectionStore: RuntimeConnectionStoring
    let operationQueue: OperationQueue
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol

    private let requestFactory: StorageRequestFactoryProtocol
    private let blockHashOperationFactory = BlockHashOperationFactory()

    init(
        runtimeConnectionStore: RuntimeConnectionStoring,
        operationQueue: OperationQueue,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    ) {
        self.runtimeConnectionStore = runtimeConnectionStore
        self.operationQueue = operationQueue
        self.blockTimeOperationFactory = blockTimeOperationFactory

        requestFactory = StorageRequestFactory.createDefault(with: operationQueue)
    }
}

private extension SubtensorRootHoldFactory {
    typealias UInt64Value = StringScaleMapper<UInt64>

    func createHoldsWrapper(
        coldkey: AccountId,
        hotkeys: [AccountId],
        engine: JSONRPCEngine,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        blockHash: Data
    ) -> CompoundOperationWrapper<[AccountId: SubtensorRootHold]> {
        let intervalWrapper: CompoundOperationWrapper<StorageResponse<UInt64Value>> = requestFactory.queryItem(
            engine: engine,
            factory: factory,
            storagePath: SubtensorStakingPallet.rootStakeUnlockIntervalPath,
            at: blockHash
        )

        let lastStakeWrapper: CompoundOperationWrapper<[StorageResponse<UInt64Value>]> = requestFactory.queryItems(
            engine: engine,
            keyParams1: { hotkeys.map { _ in BytesCodable(wrappedValue: coldkey) } },
            keyParams2: { hotkeys.map { BytesCodable(wrappedValue: $0) } },
            factory: factory,
            storagePath: SubtensorStakingPallet.lastColdkeyHotkeyStakeBlockPath,
            at: blockHash
        )

        let mergeOperation = ClosureOperation<[AccountId: SubtensorRootHold]> {
            let interval = try intervalWrapper.targetOperation.extractNoCancellableResultData().value?.value ?? 0
            let lastStakes = try lastStakeWrapper.targetOperation.extractNoCancellableResultData()

            return zip(hotkeys, lastStakes).reduce(into: [AccountId: SubtensorRootHold]()) { result, item in
                result[item.0] = SubtensorRootHold(interval: interval, lastStakeBlock: item.1.value?.value ?? 0)
            }
        }

        mergeOperation.addDependency(intervalWrapper.targetOperation)
        mergeOperation.addDependency(lastStakeWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: intervalWrapper.allOperations + lastStakeWrapper.allOperations
        )
    }
}

extension SubtensorRootHoldFactory: SubtensorRootHoldFactoryProtocol {
    func createHoldsWrapper(
        coldkey: AccountId,
        hotkeys: [AccountId]
    ) -> CompoundOperationWrapper<([AccountId: SubtensorRootHold], BlockTime)> {
        let distinctHotkeys = hotkeys.distinct()

        do {
            let engine = try runtimeConnectionStore.getConnection()
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()
            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
            let blockHashWrapper = blockHashOperationFactory.createBestBlockHashWrapper(connection: engine)
            let blockTimeWrapper = blockTimeOperationFactory.createExpectedBlockTimeWrapper(from: runtimeProvider)

            let holdsWrapper = OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                try self.createHoldsWrapper(
                    coldkey: coldkey,
                    hotkeys: distinctHotkeys,
                    engine: engine,
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    blockHash: blockHashWrapper.targetOperation.extractNoCancellableResultData()
                )
            }

            holdsWrapper.addDependency(wrapper: blockHashWrapper)
            holdsWrapper.addDependency(operations: [codingFactoryOperation])

            let mergeOperation = ClosureOperation<([AccountId: SubtensorRootHold], BlockTime)> {
                (
                    try holdsWrapper.targetOperation.extractNoCancellableResultData(),
                    try blockTimeWrapper.targetOperation.extractNoCancellableResultData()
                )
            }

            mergeOperation.addDependency(holdsWrapper.targetOperation)
            mergeOperation.addDependency(blockTimeWrapper.targetOperation)

            return holdsWrapper
                .insertingHead(operations: [codingFactoryOperation] + blockHashWrapper.allOperations)
                .insertingHead(operations: blockTimeWrapper.allOperations)
                .insertingTail(operation: mergeOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
