import Foundation
import Operation_iOS
import SubstrateSdk

enum SubtensorValidatorChainOperationError: Error {
    case missingBlockNumber
}

final class SubtensorValidatorChainOperationFactory {
    static let keysPerQuery = 256
    static let defaultTempo: UInt16 = 360
    static let defaultActivityCutoffFactorMilli: UInt32 = 13889
    static let defaultDelegateTake: UInt16 = 11796

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

private extension SubtensorValidatorChainOperationFactory {
    typealias Context = SubtensorChunkedStorageQueryFactory.Context
    typealias UInt16Value = StringScaleMapper<UInt16>
    typealias QueryWrapper<T: Decodable> = CompoundOperationWrapper<[StorageResponse<T>]>

    struct SnapshotPlan {
        let pairs: [SubtensorHotkeySubnet]
        let subnetNetuids: [UInt16]
        let hotkeys: [AccountId]
        let includesHotkeyAlpha: Bool

        init(query: SubtensorValidatorChainQuery) {
            pairs = SubtensorChunkedStorageQueryFactory.distinct(query.pairs)

            subnetNetuids = SubtensorChunkedStorageQueryFactory.distinct(
                pairs.map(\.netuid).filter { $0 != SubtensorStakingPallet.rootNetuid }
            )

            hotkeys = SubtensorChunkedStorageQueryFactory.distinct(pairs.map(\.hotkey))
            includesHotkeyAlpha = query.includesHotkeyAlpha
        }
    }

    struct SnapshotReads {
        let blockNumber: QueryWrapper<StringScaleMapper<BlockNumber>>
        let uids: QueryWrapper<UInt16Value>
        let permits: QueryWrapper<[Bool]>
        let lastUpdates: QueryWrapper<[StringScaleMapper<UInt64>]>
        let tempos: QueryWrapper<UInt16Value>
        let factors: QueryWrapper<StringScaleMapper<UInt32>>
        let takes: QueryWrapper<UInt16Value>
        let hotkeyAlpha: QueryWrapper<StringScaleMapper<Balance>>?

        var allOperations: [Operation] {
            blockNumber.allOperations + uids.allOperations + permits.allOperations +
                lastUpdates.allOperations + tempos.allOperations + factors.allOperations +
                takes.allOperations + (hotkeyAlpha?.allOperations ?? [])
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
            ] + (hotkeyAlpha.map { [$0.targetOperation] } ?? [])
        }
    }

    func createNetuidRead<T: Decodable>(
        path: StorageCodingPath,
        netuids: [UInt16],
        context: Context
    ) -> QueryWrapper<T> {
        queryFactory.createQueryWrapper(
            path: path,
            keysOperation: queryFactory.createKeysOperation(
                path: path,
                params: netuids.map { UInt16Value(value: $0) },
                codingFactoryOperation: context.codingFactoryOperation
            ),
            maxKeyCount: netuids.count,
            context: context
        )
    }

    func createPairRead<T: Decodable>(
        path: StorageCodingPath,
        pairs: [SubtensorHotkeySubnet],
        netuidFirst: Bool,
        context: Context
    ) -> QueryWrapper<T> {
        let netuids = pairs.map { UInt16Value(value: $0.netuid) }
        let hotkeys = pairs.map { BytesCodable(wrappedValue: $0.hotkey) }

        let keysOperation = netuidFirst
            ? queryFactory.createKeysOperation(
                path: path,
                params1: netuids,
                params2: hotkeys,
                codingFactoryOperation: context.codingFactoryOperation
            )
            : queryFactory.createKeysOperation(
                path: path,
                params1: hotkeys,
                params2: netuids,
                codingFactoryOperation: context.codingFactoryOperation
            )

        return queryFactory.createQueryWrapper(
            path: path,
            keysOperation: keysOperation,
            maxKeyCount: pairs.count,
            context: context
        )
    }

    func createHotkeyRead<T: Decodable>(
        path: StorageCodingPath,
        hotkeys: [AccountId],
        context: Context
    ) -> QueryWrapper<T> {
        queryFactory.createQueryWrapper(
            path: path,
            keysOperation: queryFactory.createKeysOperation(
                path: path,
                params: hotkeys.map { BytesCodable(wrappedValue: $0) },
                codingFactoryOperation: context.codingFactoryOperation
            ),
            maxKeyCount: hotkeys.count,
            context: context
        )
    }

    func createSnapshotReads(plan: SnapshotPlan, context: Context) throws -> SnapshotReads {
        typealias Pallet = SubtensorStakingPallet

        let subnets = plan.subnetNetuids

        let hotkeyAlpha: QueryWrapper<StringScaleMapper<Balance>>? = plan.includesHotkeyAlpha
            ? createPairRead(path: Pallet.totalHotkeyAlphaPath, pairs: plan.pairs, netuidFirst: false, context: context)
            : nil

        return try SnapshotReads(
            blockNumber: queryFactory.createQueryWrapper(
                path: SystemPallet.blockNumberPath,
                keysOperation: queryFactory.createPlainKeyOperation(path: SystemPallet.blockNumberPath),
                maxKeyCount: 1,
                context: context
            ),
            uids: createPairRead(path: Pallet.uidsPath, pairs: plan.pairs, netuidFirst: true, context: context),
            permits: createNetuidRead(path: Pallet.validatorPermitPath, netuids: subnets, context: context),
            lastUpdates: createNetuidRead(path: Pallet.lastUpdatePath, netuids: subnets, context: context),
            tempos: createNetuidRead(path: Pallet.tempoPath, netuids: subnets, context: context),
            factors: createNetuidRead(path: Pallet.activityCutoffFactorMilliPath, netuids: subnets, context: context),
            takes: createHotkeyRead(path: Pallet.delegatesTakePath, hotkeys: plan.hotkeys, context: context),
            hotkeyAlpha: hotkeyAlpha
        )
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

    static func createSnapshot(
        plan: SnapshotPlan,
        reads: SnapshotReads,
        blockHash: BlockHashData
    ) throws -> SubtensorValidatorChainSnapshot {
        let blockNumberResponses = try reads.blockNumber.targetOperation.extractNoCancellableResultData()

        guard let blockNumber = blockNumberResponses.first?.value?.value else {
            throw SubtensorValidatorChainOperationError.missingBlockNumber
        }

        let vectors = try extractVectors(plan: plan, reads: reads)

        let takes = try zip(plan.hotkeys, reads.takes.targetOperation.extractNoCancellableResultData())
            .reduce(into: [AccountId: UInt16]()) { result, item in
                result[item.0] = item.1.value?.value ?? defaultDelegateTake
            }

        let hotkeyAlpha = try reads.hotkeyAlpha.map { wrapper in
            try extractPairValues(pairs: plan.pairs, wrapper: wrapper) { $0.value?.value ?? 0 }
        }

        return try SubtensorValidatorChainSnapshot(
            blockHash: blockHash.toHex(includePrefix: true),
            blockNumber: blockNumber,
            uids: extractPairValues(pairs: plan.pairs, wrapper: reads.uids) { $0.value?.value },
            permits: vectors.permits,
            lastUpdates: vectors.lastUpdates,
            effectiveActivityCutoffs: extractCutoffs(plan: plan, reads: reads),
            takes: takes,
            hotkeyAlpha: hotkeyAlpha ?? [:]
        )
    }
}

private extension SubtensorValidatorChainOperationFactory {
    static func distinctOwners(hotkeys: [AccountId], owners: [AccountId: AccountId]) -> [AccountId] {
        SubtensorChunkedStorageQueryFactory.distinct(hotkeys.compactMap { owners[$0] })
    }

    func createOwnersWrapper(
        hotkeys: [AccountId],
        context: Context
    ) -> CompoundOperationWrapper<[AccountId: AccountId]> {
        let ownersWrapper: QueryWrapper<BytesCodable> = createHotkeyRead(
            path: SubtensorStakingPallet.ownerPath,
            hotkeys: hotkeys,
            context: context
        )

        let mappingOperation = ClosureOperation<[AccountId: AccountId]> {
            try zip(hotkeys, ownersWrapper.targetOperation.extractNoCancellableResultData())
                .reduce(into: [AccountId: AccountId]()) { result, item in
                    guard item.1.data != nil, let owner = item.1.value?.wrappedValue else {
                        return
                    }

                    result[item.0] = owner
                }
        }

        mappingOperation.addDependency(ownersWrapper.targetOperation)

        return ownersWrapper.insertingTail(operation: mappingOperation)
    }

    func createIdentityRecordsWrapper(
        hotkeys: [AccountId],
        ownersOperation: BaseOperation<[AccountId: AccountId]>,
        context: Context
    ) -> QueryWrapper<SubtensorStakingPallet.ChainIdentityV2> {
        let ownerParamsOperation = ClosureOperation<[BytesCodable]> {
            let owners = try ownersOperation.extractNoCancellableResultData()

            return Self.distinctOwners(hotkeys: hotkeys, owners: owners).map { BytesCodable(wrappedValue: $0) }
        }

        ownerParamsOperation.addDependency(ownersOperation)

        let wrapper: QueryWrapper<SubtensorStakingPallet.ChainIdentityV2> = queryFactory.createQueryWrapper(
            path: SubtensorStakingPallet.identitiesV2Path,
            keysOperation: queryFactory.createKeysOperation(
                path: SubtensorStakingPallet.identitiesV2Path,
                paramsOperation: ownerParamsOperation,
                codingFactoryOperation: context.codingFactoryOperation
            ),
            maxKeyCount: hotkeys.count,
            context: context
        )

        return wrapper.insertingHead(operations: [ownerParamsOperation])
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

            let context = Context(
                engine: engine,
                codingFactoryOperation: codingFactoryOperation,
                blockHashOperation: blockHashWrapper.targetOperation
            )

            let plan = SnapshotPlan(query: query)
            let reads = try createSnapshotReads(plan: plan, context: context)

            let mergeOperation = ClosureOperation<SubtensorValidatorChainSnapshot> {
                let blockHash = try blockHashWrapper.targetOperation.extractNoCancellableResultData()

                return try Self.createSnapshot(plan: plan, reads: reads, blockHash: blockHash)
            }

            reads.targetOperations.forEach { mergeOperation.addDependency($0) }
            mergeOperation.addDependency(blockHashWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mergeOperation,
                dependencies: [codingFactoryOperation] + blockHashWrapper.allOperations + reads.allOperations
            )
        } catch {
            return .createWithError(error)
        }
    }

    func createIdentitiesWrapper(
        for hotkeys: [AccountId]
    ) -> CompoundOperationWrapper<[AccountId: SubtensorValidatorIdentity]> {
        do {
            let context = try Context(
                engine: runtimeConnectionStore.getConnection(),
                codingFactoryOperation: runtimeConnectionStore.getRuntimeProvider().fetchCoderFactoryOperation(),
                blockHashOperation: nil
            )

            let distinctHotkeys = SubtensorChunkedStorageQueryFactory.distinct(hotkeys)
            let ownersWrapper = createOwnersWrapper(hotkeys: distinctHotkeys, context: context)

            let recordsWrapper = createIdentityRecordsWrapper(
                hotkeys: distinctHotkeys,
                ownersOperation: ownersWrapper.targetOperation,
                context: context
            )

            let mergeOperation = ClosureOperation<[AccountId: SubtensorValidatorIdentity]> {
                let owners = try ownersWrapper.targetOperation.extractNoCancellableResultData()
                let ownerList = Self.distinctOwners(hotkeys: distinctHotkeys, owners: owners)
                let records = try recordsWrapper.targetOperation.extractNoCancellableResultData()

                let identities = zip(ownerList, records).reduce(
                    into: [AccountId: SubtensorValidatorIdentity]()
                ) { result, item in
                    result[item.0] = item.1.value?.toValidatorIdentity()
                }

                return owners.reduce(into: [AccountId: SubtensorValidatorIdentity]()) { result, item in
                    result[item.key] = identities[item.value]
                }
            }

            mergeOperation.addDependency(recordsWrapper.targetOperation)
            mergeOperation.addDependency(ownersWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mergeOperation,
                dependencies: [context.codingFactoryOperation] + ownersWrapper.allOperations +
                    recordsWrapper.allOperations
            )
        } catch {
            return .createWithError(error)
        }
    }
}
