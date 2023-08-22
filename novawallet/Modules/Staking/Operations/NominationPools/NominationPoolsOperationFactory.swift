import Foundation
import SubstrateSdk
import RobinHood
import BigInt

protocol NominationPoolsOperationFactoryProtocol {
    func createSparePoolsInfoWrapper(
        for poolService: EraNominationPoolsServiceProtocol,
        rewardEngine: @escaping () throws -> NominationPoolsRewardEngineProtocol,
        maxMembersPerPool: @escaping () throws -> UInt32?,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[NominationPools.PoolStats]>

    func createActivePoolsInfoWrapper(
        for eraValidationService: EraValidatorServiceProtocol,
        lastPoolId: NominationPools.PoolId,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<NominationPools.ActivePools>

    func createBondedPoolsWrapper(
        for poolIds: @escaping () throws -> Set<NominationPools.PoolId>,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[NominationPools.PoolId: NominationPools.BondedPool]>

    func createMetadataWrapper(
        for poolIds: @escaping () throws -> Set<NominationPools.PoolId>,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[NominationPools.PoolId: Data]>

    func createBondedAccountsWrapper(
        for poolIds: @escaping () throws -> Set<NominationPools.PoolId>,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[NominationPools.PoolId: AccountId]>

    func createPoolsActiveStakeWrapper(
        for poolIds: @escaping () throws -> Set<NominationPools.PoolId>,
        eraValidatorService: EraValidatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[NominationPools.PoolId: BigUInt]>
}

extension NominationPoolsOperationFactoryProtocol {
    func createPoolsActiveStakeWrapper(
        for lastPoolId: NominationPools.PoolId,
        eraValidatorService: EraValidatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[NominationPools.PoolId: BigUInt]> {
        let allPoolIds = Set(0 ... lastPoolId)

        return createPoolsActiveStakeWrapper(
            for: { allPoolIds },
            eraValidatorService: eraValidatorService,
            runtimeService: runtimeService
        )
    }

    func createPoolsActiveTotalStakeWrapper(
        for lastPoolId: NominationPools.PoolId,
        eraValidatorService: EraValidatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<BigUInt> {
        let wrapper = createPoolsActiveStakeWrapper(
            for: lastPoolId,
            eraValidatorService: eraValidatorService,
            runtimeService: runtimeService
        )

        let mapOperation = ClosureOperation<BigUInt> {
            let stakes = try wrapper.targetOperation.extractNoCancellableResultData()

            return stakes.values.reduce(0) { $0 + $1 }
        }

        mapOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
    }
}

final class NominationPoolsOperationFactory {
    let requestFactory: StorageRequestFactoryProtocol

    init(operationQueue: OperationQueue) {
        requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }

    private func createPoolWrapper<T: Decodable>(
        for poolIds: @escaping () throws -> Set<NominationPools.PoolId>,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        storagePath: StorageCodingPath
    ) -> CompoundOperationWrapper<[NominationPools.PoolId: T]> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<T>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: {
                try poolIds().sorted().map { StringScaleMapper(value: $0) }
            },
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: storagePath
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<[NominationPools.PoolId: T]> {
            let metadataList = try wrapper.targetOperation.extractNoCancellableResultData()
            let poolList = try poolIds().sorted()

            return zip(poolList, metadataList).reduce(into: [NominationPools.PoolId: T]()) { accum, value in
                accum[value.0] = value.1.value
            }
        }

        mapOperation.addDependency(wrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + wrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func createSparePoolsMergeOperation(
        dependedingOn bondedPoolsOperation: BaseOperation<[NominationPools.PoolId: NominationPools.BondedPool]>,
        bondedAccountsOperation: BaseOperation<[NominationPools.PoolId: AccountId]>,
        metadataOperation: BaseOperation<[NominationPools.PoolId: Data]>,
        rewardEngine: @escaping () throws -> NominationPoolsRewardEngineProtocol,
        maxMembersPerPool: @escaping () throws -> UInt32?
    ) -> BaseOperation<[NominationPools.PoolStats]> {
        ClosureOperation<[NominationPools.PoolStats]> {
            let bondedPools = try bondedPoolsOperation.extractNoCancellableResultData()
            let bondedAccounts = try bondedAccountsOperation.extractNoCancellableResultData()
            let metadataDict = try metadataOperation.extractNoCancellableResultData()
            let maxMembersPerPool = try maxMembersPerPool()
            let rewardEngine = try rewardEngine()

            let poolStats: [NominationPools.PoolStats] = try bondedPools.keys.compactMap { poolId in
                guard
                    let bondedPool = bondedPools[poolId],
                    let bondedAccountId = bondedAccounts[poolId],
                    bondedPool.checkPoolSpare(for: maxMembersPerPool) else {
                    return nil
                }

                let maxPoolApy = try rewardEngine.calculateMaxReturn(poolId: poolId, isCompound: true, period: .year)

                return NominationPools.PoolStats(
                    poolId: poolId,
                    bondedAccountId: bondedAccountId,
                    membersCount: bondedPool.memberCounter,
                    maxApy: maxPoolApy.maxApy,
                    metadata: metadataDict[poolId]
                )
            }

            return poolStats.sorted { stat1, stat2 in
                let apy1 = stat1.maxApy ?? 0
                let apy2 = stat2.maxApy ?? 0

                return apy1 > apy2
            }
        }
    }
}

extension NominationPoolsOperationFactory: NominationPoolsOperationFactoryProtocol {
    func createActivePoolsInfoWrapper(
        for eraValidationService: EraValidatorServiceProtocol,
        lastPoolId: NominationPools.PoolId,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<NominationPools.ActivePools> {
        let validatorsOperation = eraValidationService.fetchInfoOperation()

        let allPoolIds = Set(0 ... lastPoolId)

        let poolAccountsWrapper = createBondedAccountsWrapper(
            for: { allPoolIds },
            runtimeService: runtimeService
        )

        let maxNominatorsWrapper: CompoundOperationWrapper<UInt32> = PrimitiveConstantOperation.wrapper(
            for: .maxNominatorRewardedPerValidator,
            runtimeService: runtimeService
        )

        let validatorsResolveOperation = ClosureOperation<[NominationPools.PoolId: Set<AccountId>]> {
            let poolAccounts = try poolAccountsWrapper.targetOperation.extractNoCancellableResultData()
            let activeValidators = try validatorsOperation.extractNoCancellableResultData()
            let maxRewardedNominators = try maxNominatorsWrapper.targetOperation.extractNoCancellableResultData()

            let indexedValidators = activeValidators.validators.reduce(
                into: [AccountId: Set<AccountId>]()
            ) { accum, validator in
                let allNominators = validator.exposure.others
                let targetNominators = Array(allNominators.prefix(Int(maxRewardedNominators)))

                for nominator in targetNominators {
                    let currentValidators = accum[nominator.who] ?? Set()
                    accum[nominator.who] = currentValidators.union([validator.accountId])
                }
            }

            return poolAccounts.compactMapValues { indexedValidators[$0] }
        }

        validatorsResolveOperation.addDependency(poolAccountsWrapper.targetOperation)
        validatorsResolveOperation.addDependency(validatorsOperation)
        validatorsResolveOperation.addDependency(maxNominatorsWrapper.targetOperation)

        let mapOperation = ClosureOperation<NominationPools.ActivePools> {
            let activeValidators = try validatorsOperation.extractNoCancellableResultData()

            let resolvedValidators = try validatorsResolveOperation.extractNoCancellableResultData()
            let poolAccounts = try poolAccountsWrapper.targetOperation.extractNoCancellableResultData()

            let activePools: [NominationPools.ActivePool] = allPoolIds.compactMap { poolId in
                guard
                    let validatorAccountIds = resolvedValidators[poolId],
                    let bondedAccountId = poolAccounts[poolId] else {
                    return nil
                }

                return .init(
                    poolId: poolId,
                    bondedAccountId: bondedAccountId,
                    validators: validatorAccountIds
                )
            }

            return .init(era: activeValidators.activeEra, pools: activePools)
        }

        let dependencies = [validatorsOperation] + maxNominatorsWrapper.allOperations +
            poolAccountsWrapper.allOperations + [validatorsResolveOperation]

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func createBondedPoolsWrapper(
        for poolIds: @escaping () throws -> Set<NominationPools.PoolId>,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[NominationPools.PoolId: NominationPools.BondedPool]> {
        createPoolWrapper(
            for: poolIds,
            connection: connection,
            runtimeService: runtimeService,
            storagePath: NominationPools.bondedPoolPath
        )
    }

    func createMetadataWrapper(
        for poolIds: @escaping () throws -> Set<NominationPools.PoolId>,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[NominationPools.PoolId: Data]> {
        let wrapper: CompoundOperationWrapper<[NominationPools.PoolId: BytesCodable]> = createPoolWrapper(
            for: poolIds,
            connection: connection,
            runtimeService: runtimeService,
            storagePath: NominationPools.metadataPath
        )

        let mapOperation = ClosureOperation<[NominationPools.PoolId: Data]> {
            let result = try wrapper.targetOperation.extractNoCancellableResultData()

            return result.mapValues { $0.wrappedValue }
        }

        mapOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
    }

    func createBondedAccountsWrapper(
        for poolIds: @escaping () throws -> Set<NominationPools.PoolId>,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[NominationPools.PoolId: AccountId]> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let constantOperation = StorageConstantOperation<BytesCodable>(path: NominationPools.palletIdPath)
        constantOperation.configurationBlock = {
            do {
                constantOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constantOperation.result = .failure(error)
            }
        }

        constantOperation.addDependency(codingFactoryOperation)

        let mergeOperation = ClosureOperation<[NominationPools.PoolId: AccountId]> {
            let palletId = try constantOperation.extractNoCancellableResultData().wrappedValue

            return try poolIds().reduce(into: [NominationPools.PoolId: AccountId]()) { accum, poolId in
                accum[poolId] = try NominationPools.derivedAccount(
                    for: poolId,
                    accountType: .bonded,
                    palletId: palletId
                )
            }
        }

        mergeOperation.addDependency(constantOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [codingFactoryOperation, constantOperation]
        )
    }

    func createSparePoolsInfoWrapper(
        for poolService: EraNominationPoolsServiceProtocol,
        rewardEngine: @escaping () throws -> NominationPoolsRewardEngineProtocol,
        maxMembersPerPool: @escaping () throws -> UInt32?,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[NominationPools.PoolStats]> {
        let activePoolsOperation = poolService.fetchInfoOperation()

        let poolIdsClosure: () throws -> Set<NominationPools.PoolId> = {
            let poolIds = try activePoolsOperation.extractNoCancellableResultData().pools.map(\.poolId)
            return Set(poolIds)
        }

        let bondedWrapper = createBondedPoolsWrapper(
            for: poolIdsClosure,
            connection: connection,
            runtimeService: runtimeService
        )

        let bondedAccountWrapper = createBondedAccountsWrapper(
            for: poolIdsClosure,
            runtimeService: runtimeService
        )

        let metadataWrapper = createMetadataWrapper(
            for: poolIdsClosure,
            connection: connection,
            runtimeService: runtimeService
        )

        bondedWrapper.addDependency(operations: [activePoolsOperation])
        bondedAccountWrapper.addDependency(operations: [activePoolsOperation])
        metadataWrapper.addDependency(operations: [activePoolsOperation])

        let mergeOperation = createSparePoolsMergeOperation(
            dependedingOn: bondedWrapper.targetOperation,
            bondedAccountsOperation: bondedAccountWrapper.targetOperation,
            metadataOperation: metadataWrapper.targetOperation,
            rewardEngine: rewardEngine,
            maxMembersPerPool: maxMembersPerPool
        )

        let dependencies = [activePoolsOperation] + bondedWrapper.allOperations + bondedAccountWrapper.allOperations +
            metadataWrapper.allOperations

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func createPoolsActiveStakeWrapper(
        for poolIds: @escaping () throws -> Set<NominationPools.PoolId>,
        eraValidatorService: EraValidatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[NominationPools.PoolId: BigUInt]> {
        let bondedAccountIdWrapper = createBondedAccountsWrapper(
            for: poolIds,
            runtimeService: runtimeService
        )

        let validatorsOperation = eraValidatorService.fetchInfoOperation()

        let mapOperation = ClosureOperation<[NominationPools.PoolId: BigUInt]> {
            let validators = try validatorsOperation.extractNoCancellableResultData()
            let poolAccountIds = try bondedAccountIdWrapper.targetOperation.extractNoCancellableResultData()

            let stakeByAccountId = validators.validators.reduce(into: [AccountId: BigUInt]()) { accum, validator in
                accum[validator.accountId] = validator.exposure.own

                for nominator in validator.exposure.others {
                    let prevStake = accum[nominator.who] ?? 0
                    accum[nominator.who] = prevStake + nominator.value
                }
            }

            return poolAccountIds.reduce(into: [NominationPools.PoolId: BigUInt]()) { accum, keyValue in
                accum[keyValue.key] = stakeByAccountId[keyValue.value]
            }
        }

        mapOperation.addDependency(bondedAccountIdWrapper.targetOperation)
        mapOperation.addDependency(validatorsOperation)

        let dependencies = bondedAccountIdWrapper.allOperations + [validatorsOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
