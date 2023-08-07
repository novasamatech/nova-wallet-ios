import Foundation
import RobinHood
import SubstrateSdk

protocol NominationPoolRecommendationFactoryProtocol: AnyObject {
    func createPoolRecommendationWrapper() -> CompoundOperationWrapper<NominationPools.SelectedPool>
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
    func createPoolRecommendationWrapper() -> CompoundOperationWrapper<NominationPools.SelectedPool> {
        let maxApyWrapper = rewardEngineOperationFactory.createEngineWrapper(
            for: eraPoolsService,
            validatorRewardService: validatorRewardService,
            connection: connection,
            runtimeService: runtimeService
        )

        let activePoolsOperation = eraPoolsService.fetchInfoOperation()

        let bondedPoolsWrapper = storageOperationFactory.createBondedPoolsWrapper(
            for: {
                let allPoolIds = try activePoolsOperation.extractNoCancellableResultData().pools.map(\.poolId)
                return Set(allPoolIds)
            },
            connection: connection,
            runtimeService: runtimeService
        )

        bondedPoolsWrapper.addDependency(operations: [activePoolsOperation])

        let maxApyPoolOperation = ClosureOperation<NominationPools.PoolApy> {
            let validPoolIds = try bondedPoolsWrapper.targetOperation
                .extractNoCancellableResultData()
                .filter { $0.value.state == .open }
                .map(\.key)

            let rewardEngine = try maxApyWrapper.targetOperation.extractNoCancellableResultData()

            let optMaxApy = try validPoolIds
                .map { try rewardEngine.calculateMaxReturn(poolId: $0, isCompound: true, period: .year) }
                .max { $0.maxApy < $1.maxApy }

            guard let maxApy = optMaxApy else {
                throw NominationPoolRecommendationFactoryError.noPoolToJoin
            }

            return maxApy
        }

        maxApyPoolOperation.addDependency(maxApyWrapper.targetOperation)
        maxApyPoolOperation.addDependency(bondedPoolsWrapper.targetOperation)

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

        let dependencies = maxApyWrapper.allOperations + [activePoolsOperation] + bondedPoolsWrapper.allOperations +
            [maxApyPoolOperation] + metadataWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
