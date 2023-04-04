import Foundation
import SubstrateSdk

protocol RewardCalculatorParamsServiceFactoryProtocol {
    func createRewardCalculatorParamsService() -> RewardCalculatorParamsServiceProtocol
}

final class RewardCalculatorParamsServiceFactory {
    let stakingType: StakingType
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue

    init(
        stakingType: StakingType,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.stakingType = stakingType
        self.connection = connection
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue
    }
}

extension RewardCalculatorParamsServiceFactory: RewardCalculatorParamsServiceFactoryProtocol {
    func createRewardCalculatorParamsService() -> RewardCalculatorParamsServiceProtocol {
        switch stakingType {
        case .relaychain:
            return InflationRewardCalculatorParamsService(
                connection: connection,
                runtimeService: runtimeService,
                operationQueue: operationQueue
            )
        default:
            return NoRewardCalculatorParamsService()
        }
    }
}
