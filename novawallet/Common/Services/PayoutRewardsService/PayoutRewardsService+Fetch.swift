import Operation_iOS
import SubstrateSdk
import BigInt
import NovaCrypto

extension PayoutRewardsService {
    func createChainHistoryRangeOperationWrapper(
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) throws -> CompoundOperationWrapper<ChainHistoryRange> {
        let keyFactory = StorageKeyFactory()

        let currentEraWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.currentEra()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: Staking.currentEra
            )

        let activeEraWrapper: CompoundOperationWrapper<[StorageResponse<Staking.ActiveEraInfo>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.activeEra()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: Staking.activeEra
            )

        let historyDepthWrapper = createHistoryDepthWrapper(
            dependingOn: codingFactoryOperation,
            storageRequestFactory: storageRequestFactory,
            connection: engine
        )

        let dependecies = currentEraWrapper.allOperations + activeEraWrapper.allOperations
            + historyDepthWrapper.allOperations
        dependecies.forEach { $0.addDependency(codingFactoryOperation) }

        let mergeOperation = ClosureOperation<ChainHistoryRange> {
            guard
                let currentEra = try currentEraWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.value,
                let activeEra = try activeEraWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.index,
                let historyDepth = try historyDepthWrapper.targetOperation.extractNoCancellableResultData()
            else {
                throw PayoutRewardsServiceError.unknown
            }

            return ChainHistoryRange(
                currentEra: currentEra,
                activeEra: activeEra,
                historyDepth: historyDepth
            )
        }

        dependecies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependecies)
    }

    func createHistoryDepthWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        storageRequestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<UInt32?> {
        let combiningService = OperationCombiningService<UInt32?>(operationManager: operationManager) {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let runtimeMetadata = codingFactory.metadata

            if runtimeMetadata.getStorageMetadata(for: Staking.historyDepthStoragePath) != nil {
                let wrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<UInt32>>> =
                    storageRequestFactory.queryItem(
                        engine: connection,
                        factory: { codingFactory },
                        storagePath: Staking.historyDepthStoragePath
                    )

                let mapOperation = ClosureOperation<UInt32?> {
                    try wrapper.targetOperation.extractNoCancellableResultData().value?.value
                }

                mapOperation.addDependency(wrapper.targetOperation)

                return [CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)]
            } else {
                let constantFetchOperation = PrimitiveConstantOperation<UInt32>(
                    path: Staking.historyDepthCostantPath
                )

                constantFetchOperation.codingFactory = codingFactory

                let mapOperation = ClosureOperation<UInt32?> {
                    try constantFetchOperation.extractNoCancellableResultData()
                }

                mapOperation.addDependency(constantFetchOperation)

                return [CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [constantFetchOperation])]
            }
        }

        let historyDepthFetchOperation = combiningService.longrunOperation()

        let mapOperation = ClosureOperation<UInt32?> {
            try historyDepthFetchOperation.extractNoCancellableResultData().first ?? nil
        }

        mapOperation.addDependency(historyDepthFetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [historyDepthFetchOperation])
    }

    func createFetchHistoryByEraOperation<T: Decodable>(
        dependingOn erasOperation: BaseOperation<[Staking.EraIndex]>,
        engine: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        path: StorageCodingPath
    ) throws -> CompoundOperationWrapper<[Staking.EraIndex: T]> {
        let keyParams: () throws -> [StringScaleMapper<Staking.EraIndex>] = {
            let eras = try erasOperation.extractNoCancellableResultData()
            return eras.map { StringScaleMapper(value: $0) }
        }

        let wrapper: CompoundOperationWrapper<[StorageResponse<T>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: keyParams,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: path
            )

        let mergeOperation = ClosureOperation<[Staking.EraIndex: T]> {
            let eras = try keyParams()

            let results = try wrapper.targetOperation.extractNoCancellableResultData()
                .enumerated()
                .reduce(into: [Staking.EraIndex: T]()) { dict, item in
                    guard let result = item.element.value else {
                        return
                    }

                    let era = eras[item.offset].value
                    dict[era] = result
                }
            return results
        }

        wrapper.allOperations.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: wrapper.allOperations
        )
    }

    func createErasRewardDistributionOperationWrapper(
        dependingOn unclaimedErasClosure: @escaping () throws -> [StakingUnclaimedReward],
        engine: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) throws -> CompoundOperationWrapper<ErasRewardDistribution> {
        let erasOperation = ClosureOperation<[Staking.EraIndex]> {
            try unclaimedErasClosure().map(\.era).distinct()
        }

        let totalRewardOperation: CompoundOperationWrapper<[Staking.EraIndex: StringScaleMapper<BigUInt>]> =
            try createFetchHistoryByEraOperation(
                dependingOn: erasOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation,
                path: Staking.totalValidatorReward
            )

        totalRewardOperation.allOperations.forEach {
            $0.addDependency(codingFactoryOperation)
            $0.addDependency(erasOperation)
        }

        let validatorRewardPoints: CompoundOperationWrapper<[Staking.EraIndex: Staking.EraRewardPoints]> =
            try createFetchHistoryByEraOperation(
                dependingOn: erasOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation,
                path: Staking.rewardPointsPerValidator
            )

        validatorRewardPoints.allOperations.forEach {
            $0.addDependency(codingFactoryOperation)
            $0.addDependency(erasOperation)
        }

        let mergeOperation = ClosureOperation<ErasRewardDistribution> {
            let totalValidatorRewardByEra = try totalRewardOperation
                .targetOperation.extractNoCancellableResultData()
            let validatorRewardPoints = try validatorRewardPoints
                .targetOperation.extractNoCancellableResultData()

            return ErasRewardDistribution(
                totalValidatorRewardByEra: totalValidatorRewardByEra.mapValues { $0.value },
                validatorPointsDistributionByEra: validatorRewardPoints
            )
        }

        let mergeOperationDependencies = [erasOperation] + totalRewardOperation.allOperations +
            validatorRewardPoints.allOperations
        mergeOperationDependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: mergeOperationDependencies
        )
    }

    func createValidatorPrefsWrapper(
        dependingOn unclaimedRewards: @escaping () throws -> [StakingUnclaimedReward],
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) throws -> CompoundOperationWrapper<[ResolvedValidatorEra: Staking.ValidatorPrefs]> {
        let keysOperation = ClosureOperation<[ResolvedValidatorEra]> {
            try unclaimedRewards().map { ResolvedValidatorEra(validator: $0.accountId, era: $0.era) }.distinct()
        }

        let keyParams1: () throws -> [StringScaleMapper<Staking.EraIndex>] = {
            let keys = try keysOperation.extractNoCancellableResultData()
            return keys.map { StringScaleMapper(value: $0.era) }
        }

        let keyParams2: () throws -> [BytesCodable] = {
            let keys = try keysOperation.extractNoCancellableResultData()
            return keys.map { BytesCodable(wrappedValue: $0.validator) }
        }

        let wrapper: CompoundOperationWrapper<[StorageResponse<Staking.ValidatorPrefs>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams1: keyParams1,
                keyParams2: keyParams2,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: Staking.eraValidatorPrefs
            )

        wrapper.addDependency(operations: [keysOperation])

        let mergeOperation = ClosureOperation<[ResolvedValidatorEra: Staking.ValidatorPrefs]> {
            let responses = try wrapper.targetOperation.extractNoCancellableResultData()
            let keys = try keysOperation.extractNoCancellableResultData()

            return responses.enumerated().reduce(into: [ResolvedValidatorEra: Staking.ValidatorPrefs]()) { result, item in
                guard let value = item.element.value else {
                    return
                }

                let key = keys[item.offset]
                result[key] = value
            }
        }

        wrapper.allOperations.forEach { mergeOperation.addDependency($0) }

        return wrapper
            .insertingHead(operations: [keysOperation])
            .insertingTail(operation: mergeOperation)
    }

    // swiftlint:disable:next function_parameter_count
    func calculatePayouts(
        for payoutInfoFactory: PayoutInfoFactoryProtocol,
        eraValidatorsOperation: BaseOperation<[StakingValidatorExposure]>,
        unclaimedRewardsOperation: BaseOperation<[StakingUnclaimedReward]>,
        prefsOperation: BaseOperation<[ResolvedValidatorEra: Staking.ValidatorPrefs]>,
        erasRewardOperation: BaseOperation<ErasRewardDistribution>,
        historyRangeOperation: BaseOperation<ChainHistoryRange>,
        identityOperation: BaseOperation<[AccountAddress: AccountIdentity]>
    ) throws -> BaseOperation<Staking.PayoutsInfo> {
        let targetAccountId = try selectedAccountAddress.toAccountId()

        return ClosureOperation<Staking.PayoutsInfo> {
            let validatorsByEra = try eraValidatorsOperation.extractNoCancellableResultData().reduce(
                into: [ResolvedValidatorEra: StakingValidatorExposure]()
            ) { accum, exposure in
                let validatorEra = ResolvedValidatorEra(validator: exposure.accountId, era: exposure.era)
                accum[validatorEra] = exposure
            }

            let erasRewardDistribution = try erasRewardOperation.extractNoCancellableResultData()
            let identities = try identityOperation.extractNoCancellableResultData()
            let prefsDic = try prefsOperation.extractNoCancellableResultData()
            let unclaimedRewards = try unclaimedRewardsOperation.extractNoCancellableResultData()

            let payouts: [Staking.PayoutInfo] = try unclaimedRewards.compactMap { unclaimedReward in
                let validatorEra = ResolvedValidatorEra(validator: unclaimedReward.accountId, era: unclaimedReward.era)
                guard let exposure = validatorsByEra[validatorEra], let prefs = prefsDic[validatorEra] else {
                    return nil
                }

                let params = PayoutInfoFactoryParams(
                    unclaimedRewards: unclaimedReward,
                    exposure: exposure,
                    prefs: prefs,
                    rewardDistribution: erasRewardDistribution,
                    identities: identities
                )

                return try payoutInfoFactory.calculate(for: targetAccountId, params: params)
            }

            let overview = try historyRangeOperation.extractNoCancellableResultData()
            let sortedPayouts = payouts.sorted { $0.era < $1.era }

            return Staking.PayoutsInfo(
                activeEra: overview.activeEra,
                historyDepth: overview.historyDepth,
                payouts: sortedPayouts
            )
        }
    }
}
