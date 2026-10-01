import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorRootHoldFactoryProtocol {
    func createHoldsWrapper(
        coldkey: AccountId,
        hotkeys: [AccountId]
    ) -> CompoundOperationWrapper<[AccountId: SubtensorRootHold]>
}

extension SubtensorRootHold {
    func remainingBlocks(at head: UInt64) -> UInt64 {
        let elapsed = head > lastStakeBlock ? head - lastStakeBlock : 0

        return elapsed >= interval ? 0 : interval - elapsed
    }
}

final class SubtensorRootHoldFactory {
    static let keysPerQuery = 256

    let runtimeConnectionStore: RuntimeConnectionStoring

    private let queryFactory: SubtensorChunkedStorageQueryFactory
    private let blockHashOperationFactory = BlockHashOperationFactory()

    init(
        runtimeConnectionStore: RuntimeConnectionStoring,
        timeout: Int = JSONRPCTimeout.singleNode
    ) {
        self.runtimeConnectionStore = runtimeConnectionStore

        queryFactory = SubtensorChunkedStorageQueryFactory(keysPerQuery: Self.keysPerQuery, timeout: timeout)
    }
}

private extension SubtensorRootHoldFactory {
    typealias UInt64Wrapper = CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt64>>]>

    func createIntervalWrapper(context: SubtensorChunkedStorageQueryFactory.Context) throws -> UInt64Wrapper {
        let path = SubtensorStakingPallet.rootStakeUnlockIntervalPath

        return try queryFactory.createQueryWrapper(
            path: path,
            keysOperation: queryFactory.createPlainKeyOperation(path: path),
            maxKeyCount: 1,
            context: context
        )
    }

    func createLastStakeWrapper(
        coldkey: AccountId,
        hotkeys: [AccountId],
        context: SubtensorChunkedStorageQueryFactory.Context
    ) -> UInt64Wrapper {
        queryFactory.createQueryWrapper(
            path: SubtensorStakingPallet.lastColdkeyHotkeyStakeBlockPath,
            keysOperation: queryFactory.createKeysOperation(
                path: SubtensorStakingPallet.lastColdkeyHotkeyStakeBlockPath,
                params1: hotkeys.map { _ in BytesCodable(wrappedValue: coldkey) },
                params2: hotkeys.map { BytesCodable(wrappedValue: $0) },
                codingFactoryOperation: context.codingFactoryOperation
            ),
            maxKeyCount: hotkeys.count,
            context: context
        )
    }
}

extension SubtensorRootHoldFactory: SubtensorRootHoldFactoryProtocol {
    func createHoldsWrapper(
        coldkey: AccountId,
        hotkeys: [AccountId]
    ) -> CompoundOperationWrapper<[AccountId: SubtensorRootHold]> {
        let distinctHotkeys = SubtensorChunkedStorageQueryFactory.distinct(hotkeys)

        guard !distinctHotkeys.isEmpty else {
            return .createWithResult([:])
        }

        do {
            let engine = try runtimeConnectionStore.getConnection()
            let codingFactoryOperation = try runtimeConnectionStore.getRuntimeProvider().fetchCoderFactoryOperation()
            let blockHashWrapper = blockHashOperationFactory.createBestBlockHashWrapper(connection: engine)

            let context = SubtensorChunkedStorageQueryFactory.Context(
                engine: engine,
                codingFactoryOperation: codingFactoryOperation,
                blockHashOperation: blockHashWrapper.targetOperation
            )

            let intervalWrapper = try createIntervalWrapper(context: context)
            let lastStakeWrapper = createLastStakeWrapper(coldkey: coldkey, hotkeys: distinctHotkeys, context: context)

            let mergeOperation = ClosureOperation<[AccountId: SubtensorRootHold]> {
                let interval = try intervalWrapper.targetOperation.extractNoCancellableResultData()
                    .first?.value?.value ?? 0

                let lastStakes = try lastStakeWrapper.targetOperation.extractNoCancellableResultData()

                return zip(distinctHotkeys, lastStakes).reduce(into: [AccountId: SubtensorRootHold]()) { result, item in
                    result[item.0] = SubtensorRootHold(interval: interval, lastStakeBlock: item.1.value?.value ?? 0)
                }
            }

            mergeOperation.addDependency(intervalWrapper.targetOperation)
            mergeOperation.addDependency(lastStakeWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mergeOperation,
                dependencies: [codingFactoryOperation] + blockHashWrapper.allOperations +
                    intervalWrapper.allOperations + lastStakeWrapper.allOperations
            )
        } catch {
            return .createWithError(error)
        }
    }
}
