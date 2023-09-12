import Foundation
import RobinHood
import SubstrateSdk

protocol NominationPoolRecommendationFactoryProtocol: AnyObject {
    func createPoolRecommendationWrapper(
        for maxMembersPerPool: UInt32?,
        preferrablePool: NominationPools.PoolId?
    ) -> CompoundOperationWrapper<NominationPools.SelectedPool>
}

enum NominationPoolRecommendationFactoryError: Error {
    case noPoolToJoin
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
    func createPoolRecommendationWrapper(
        for maxMembersPerPool: UInt32?,
        preferrablePool: NominationPools.PoolId?
    ) -> CompoundOperationWrapper<NominationPools.SelectedPool> {
        let maxApyWrapper = rewardEngineOperationFactory.createEngineWrapper(
            for: eraPoolsService,
            validatorRewardService: validatorRewardService,
            connection: connection,
            runtimeService: runtimeService
        )

        let params = RecommendedNominationPoolsParams(
            maxMembersPerPool: { maxMembersPerPool },
            preferrablePool: { preferrablePool }
        )

        let poolStatsWrapper = storageOperationFactory.createPoolRecommendationsInfoWrapper(
            for: eraPoolsService,
            rewardEngine: {
                try maxApyWrapper.targetOperation.extractNoCancellableResultData()
            },
            params: params,
            connection: connection,
            runtimeService: runtimeService
        )

        poolStatsWrapper.addDependency(wrapper: maxApyWrapper)

        let mergeOperation = ClosureOperation<NominationPools.SelectedPool> {
            let poolStatsList = try poolStatsWrapper.targetOperation.extractNoCancellableResultData()

            guard let maxPoolStats = poolStatsList.first else {
                throw NominationPoolRecommendationFactoryError.noPoolToJoin
            }

            return .init(
                poolId: maxPoolStats.poolId,
                bondedAccountId: maxPoolStats.bondedAccountId,
                metadata: maxPoolStats.metadata,
                maxApy: maxPoolStats.maxApy
            )
        }

        mergeOperation.addDependency(poolStatsWrapper.targetOperation)

        let dependencies = maxApyWrapper.allOperations + poolStatsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
