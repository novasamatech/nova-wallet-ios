import Foundation
import Operation_iOS
import SubstrateSdk

enum SubtensorValidatorChainOperationError: Error {
    case missingBlockNumber
}

final class SubtensorValidatorChainOperationFactory {
    static let defaultTempo: UInt16 = 360
    static let defaultActivityCutoffFactorMilli: UInt32 = 13889
    static let defaultDelegateTake: UInt16 = 11796

    let runtimeConnectionStore: RuntimeConnectionStoring
    let operationQueue: OperationQueue

    private let requestFactory: StorageRequestFactoryProtocol
    private let blockHashOperationFactory = BlockHashOperationFactory()

    init(runtimeConnectionStore: RuntimeConnectionStoring, operationQueue: OperationQueue) {
        self.runtimeConnectionStore = runtimeConnectionStore
        self.operationQueue = operationQueue

        requestFactory = StorageRequestFactory.createDefault(with: operationQueue)
    }
}

private extension SubtensorValidatorChainOperationFactory {
    typealias UInt16Value = StringScaleMapper<UInt16>
    typealias QueryWrapper<T: Decodable> = CompoundOperationWrapper<[StorageResponse<T>]>

    struct Context {
        let engine: JSONRPCEngine
        let factory: () throws -> RuntimeCoderFactoryProtocol
        let blockHash: Data
    }

    struct SnapshotPlan {
        let pairs: [SubtensorHotkeySubnet]
        let subnetNetuids: [UInt16]
        let hotkeys: [AccountId]

        init(query: SubtensorValidatorChainQuery) {
            pairs = query.pairs.distinct()
            subnetNetuids = pairs.map(\.netuid).filter { $0 != SubtensorStakingPallet.rootNetuid }.distinct()
            hotkeys = (pairs.map(\.hotkey) + query.takeHotkeys).distinct()
        }
    }

    struct SnapshotReads {
        let blockNumber: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BlockNumber>>>
        let uids: QueryWrapper<UInt16Value>
        let permits: QueryWrapper<[Bool]>
        let lastUpdates: QueryWrapper<[StringScaleMapper<UInt64>]>
        let tempos: QueryWrapper<UInt16Value>
        let factors: QueryWrapper<StringScaleMapper<UInt32>>
        let takes: QueryWrapper<UInt16Value>

        var allOperations: [Operation] {
            blockNumber.allOperations + uids.allOperations + permits.allOperations +
                lastUpdates.allOperations + tempos.allOperations + factors.allOperations +
                takes.allOperations
        }

        var targetOperations: [Operation] {
            [
                blockNumber.targetOperation,
                uids.targetOperation,
                permits.targetOperation,
                lastUpdates.targetOperation,
                tempos.targetOperation,
                factors.targetOperation,
                takes.targetOperation
            ]
        }
    }

    func createNetuidRead<T: Decodable>(
        path: StorageCodingPath,
        netuids: [UInt16],
        context: Context
    ) -> QueryWrapper<T> {
        requestFactory.queryItems(
            engine: context.engine,
            keyParams: { netuids.map { UInt16Value(value: $0) } },
            factory: context.factory,
            storagePath: path,
            at: context.blockHash
        )
    }

    func createSnapshotReads(plan: SnapshotPlan, context: Context) -> SnapshotReads {
        typealias Pallet = SubtensorStakingPallet

        let subnets = plan.subnetNetuids

        return SnapshotReads(
            blockNumber: requestFactory.queryItem(
                engine: context.engine,
                factory: context.factory,
                storagePath: SystemPallet.blockNumberPath,
                at: context.blockHash
            ),
            uids: requestFactory.queryItems(
                engine: context.engine,
                keyParams1: { plan.pairs.map { UInt16Value(value: $0.netuid) } },
                keyParams2: { plan.pairs.map { BytesCodable(wrappedValue: $0.hotkey) } },
                factory: context.factory,
                storagePath: Pallet.uidsPath,
                at: context.blockHash
            ),
            permits: createNetuidRead(path: Pallet.validatorPermitPath, netuids: subnets, context: context),
            lastUpdates: createNetuidRead(path: Pallet.lastUpdatePath, netuids: subnets, context: context),
            tempos: createNetuidRead(path: Pallet.tempoPath, netuids: subnets, context: context),
            factors: createNetuidRead(path: Pallet.activityCutoffFactorMilliPath, netuids: subnets, context: context),
            takes: requestFactory.queryItems(
                engine: context.engine,
                keyParams: { plan.hotkeys.map { BytesCodable(wrappedValue: $0) } },
                factory: context.factory,
                storagePath: Pallet.delegatesTakePath,
                at: context.blockHash
            )
        )
    }

    func createSnapshotWrapper(
        plan: SnapshotPlan,
        context: Context
    ) -> CompoundOperationWrapper<SubtensorValidatorChainSnapshot> {
        let reads = createSnapshotReads(plan: plan, context: context)

        let mergeOperation = ClosureOperation<SubtensorValidatorChainSnapshot> {
            try Self.createSnapshot(plan: plan, reads: reads)
        }

        reads.targetOperations.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: reads.allOperations)
    }
}

private extension SubtensorValidatorChainOperationFactory {
    static func extractCutoffs(plan: SnapshotPlan, reads: SnapshotReads) throws -> [UInt16: UInt64] {
        let tempos = try reads.tempos.targetOperation.extractNoCancellableResultData()
        let factors = try reads.factors.targetOperation.extractNoCancellableResultData()

        return zip(plan.subnetNetuids, zip(tempos, factors)).reduce(into: [UInt16: UInt64]()) { result, item in
            let tempo = item.1.0.value?.value ?? defaultTempo
            let factor = item.1.1.value?.value ?? defaultActivityCutoffFactorMilli

            result[item.0] = SubtensorValidatorChainStatus.effectiveActivityCutoff(
                factorMilli: UInt64(factor),
                tempo: UInt64(tempo)
            )
        }
    }

    static func extractVectors(
        plan: SnapshotPlan,
        reads: SnapshotReads
    ) throws -> (permits: [UInt16: [Bool]], lastUpdates: [UInt16: [UInt64]]) {
        let permitResponses = try reads.permits.targetOperation.extractNoCancellableResultData()
        let lastUpdateResponses = try reads.lastUpdates.targetOperation.extractNoCancellableResultData()

        let permits = zip(plan.subnetNetuids, permitResponses).reduce(into: [UInt16: [Bool]]()) { result, item in
            result[item.0] = item.1.value ?? []
        }

        let lastUpdates = zip(plan.subnetNetuids, lastUpdateResponses).reduce(
            into: [UInt16: [UInt64]]()
        ) { result, item in
            result[item.0] = item.1.value?.map(\.value) ?? []
        }

        return (permits, lastUpdates)
    }

    static func extractPairValues<T: Decodable, V>(
        pairs: [SubtensorHotkeySubnet],
        wrapper: QueryWrapper<T>,
        mapping: (StorageResponse<T>) -> V?
    ) throws -> [SubtensorHotkeySubnet: V] {
        try zip(pairs, wrapper.targetOperation.extractNoCancellableResultData())
            .reduce(into: [SubtensorHotkeySubnet: V]()) { result, item in
                if let value = mapping(item.1) {
                    result[item.0] = value
                }
            }
    }

    static func createSnapshot(plan: SnapshotPlan, reads: SnapshotReads) throws -> SubtensorValidatorChainSnapshot {
        let blockNumberResponse = try reads.blockNumber.targetOperation.extractNoCancellableResultData()

        guard let blockNumber = blockNumberResponse.value?.value else {
            throw SubtensorValidatorChainOperationError.missingBlockNumber
        }

        let vectors = try extractVectors(plan: plan, reads: reads)

        let takes = try zip(plan.hotkeys, reads.takes.targetOperation.extractNoCancellableResultData())
            .reduce(into: [AccountId: UInt16]()) { result, item in
                result[item.0] = item.1.value?.value ?? defaultDelegateTake
            }

        return try SubtensorValidatorChainSnapshot(
            blockNumber: blockNumber,
            uids: extractPairValues(pairs: plan.pairs, wrapper: reads.uids) { $0.value?.value },
            permits: vectors.permits,
            lastUpdates: vectors.lastUpdates,
            effectiveActivityCutoffs: extractCutoffs(plan: plan, reads: reads),
            takes: takes
        )
    }
}

extension SubtensorValidatorChainOperationFactory: SubtensorValidatorChainOperationFactoryProtocol {
    func createChainSnapshotWrapper(
        for query: SubtensorValidatorChainQuery
    ) -> CompoundOperationWrapper<SubtensorValidatorChainSnapshot> {
        do {
            let engine = try runtimeConnectionStore.getConnection()
            let codingFactoryOperation = try runtimeConnectionStore.getRuntimeProvider().fetchCoderFactoryOperation()
            let blockHashWrapper = blockHashOperationFactory.createBestBlockHashWrapper(connection: engine)
            let plan = SnapshotPlan(query: query)

            let snapshotWrapper = OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let context = try Context(
                    engine: engine,
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    blockHash: blockHashWrapper.targetOperation.extractNoCancellableResultData()
                )

                return self.createSnapshotWrapper(plan: plan, context: context)
            }

            snapshotWrapper.addDependency(wrapper: blockHashWrapper)
            snapshotWrapper.addDependency(operations: [codingFactoryOperation])

            return snapshotWrapper.insertingHead(operations: [codingFactoryOperation] + blockHashWrapper.allOperations)
        } catch {
            return .createWithError(error)
        }
    }
}
