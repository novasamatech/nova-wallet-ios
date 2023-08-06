import Foundation
import RobinHood
import SubstrateSdk

protocol NominationPoolRecommendationFactoryProtocol: AnyObject {
    func createPoolRecommendationWrapper() -> CompoundOperationWrapper<NominationPools.SelectedPool>
}

final class NominationPoolRecommendationFactory {
    let eraPoolsService: EraNominationPoolsServiceProtocol
    let validatorRewardService: RewardCalculatorServiceProtocol
    let rewardEngineOperationFactory: NPoolsRewardEngineFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let storageOperationFactory: NominationPoolsOperationFactoryProtocol

    init(
        eraPoolsService: EraNominationPoolsServiceProtocol,
        validatorRewardService: RewardCalculatorServiceProtocol,
        rewardEngineOperationFactory: NPoolsRewardEngineFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        storageOperationFactory: NominationPoolsOperationFactoryProtocol
    ) {
        self.eraPoolsService = eraPoolsService
        self.validatorRewardService = validatorRewardService
        self.rewardEngineOperationFactory = rewardEngineOperationFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.storageOperationFactory = storageOperationFactory
    }
}

extension NominationPoolRecommendationFactory: NominationPoolRecommendationFactoryProtocol {
    func createPoolRecommendationWrapper() -> CompoundOperationWrapper<NominationPools.SelectedPool> {
        let maxApyWrapper = rewardEngineOperationFactory.createEngineWrapper(
            for: eraPoolsService,
            validatorRewardService: validatorRewardService,
            connection: connection,
            runtimeService: runtimeService
        )

        let maxApyPoolOperation = ClosureOperation<NominationPools.PoolApy> {
            try maxApyWrapper.targetOperation.extractNoCancellableResultData().calculateMaxReturn(
                isCompound: true,
                period: .year
            )
        }

        maxApyPoolOperation.addDependency(maxApyWrapper.targetOperation)

        let metadataWrapper = storageOperationFactory.createMetadataWrapper(
            for: {
                let poolId = try maxApyPoolOperation.extractNoCancellableResultData().poolId

                return [poolId]
            },
            connection: connection,
            runtimeService: runtimeService
        )

        metadataWrapper.addDependency(operations: [maxApyPoolOperation])

        let mergeOperation = ClosureOperation<NominationPools.SelectedPool> {
            let metadataDict = try metadataWrapper.targetOperation.extractNoCancellableResultData()
            let poolApy = try maxApyPoolOperation.extractNoCancellableResultData()

            return .init(
                poolId: poolApy.poolId,
                bondedAccountId: poolApy.bondedAccountId,
                metadata: metadataDict[poolApy.poolId],
                maxApy: poolApy.maxApy
            )
        }

        mergeOperation.addDependency(metadataWrapper.targetOperation)
        mergeOperation.addDependency(maxApyPoolOperation)

        let dependencies = maxApyWrapper.allOperations + [maxApyPoolOperation] + metadataWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
