import Foundation
import RobinHood
import SubstrateSdk

protocol NPoolsRewardEngineFactoryProtocol {
    func createEngineWrapper(
        for eraPoolsService: EraNominationPoolsServiceProtocol,
        validatorRewardService: RewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<NominationPoolsRewardEngineProtocol>
}

final class NPoolsRewardEngineFactory {
    let operationFactory: NominationPoolsOperationFactoryProtocol

    init(operationFactory: NominationPoolsOperationFactoryProtocol) {
        self.operationFactory = operationFactory
    }
}

extension NPoolsRewardEngineFactory: NPoolsRewardEngineFactoryProtocol {
    func createEngineWrapper(
        for eraPoolsService: EraNominationPoolsServiceProtocol,
        validatorRewardService: RewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<NominationPoolsRewardEngineProtocol> {
        let activePoolsOperation = eraPoolsService.fetchInfoOperation()
        let rewardEngineOperation = validatorRewardService.fetchCalculatorOperation()

        let bondingDetailsWrapper = operationFactory.createBondedPoolsWrapper(
            for: {
                let poolIds = try activePoolsOperation.extractNoCancellableResultData().pools.map(\.poolId)
                return Set(poolIds)
            },
            connection: connection,
            runtimeService: runtimeService
        )

        bondingDetailsWrapper.addDependency(operations: [activePoolsOperation])

        let mergeOperation = ClosureOperation<NominationPoolsRewardEngineProtocol> {
            let validatorRewardCalculator = try rewardEngineOperation.extractNoCancellableResultData()
            let activePools = try activePoolsOperation.extractNoCancellableResultData().pools.reduce(
                into: [NominationPools.PoolId: NominationPools.ActivePool]()
            ) {
                $0[$1.poolId] = $1
            }

            let bondingDetails = try bondingDetailsWrapper.targetOperation.extractNoCancellableResultData()

            let engine = NominationPoolsRewardEngine(
                innerRewardCalculator: validatorRewardCalculator,
                activePools: activePools,
                bondingDetails: bondingDetails
            )

            engine.setup()

            return engine
        }

        let dependencies = [activePoolsOperation, rewardEngineOperation] + bondingDetailsWrapper.allOperations

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
