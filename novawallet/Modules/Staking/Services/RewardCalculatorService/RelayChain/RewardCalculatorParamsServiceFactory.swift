import Foundation
import SubstrateSdk

protocol RewardCalculatorParamsServiceFactoryProtocol {
    func createRewardCalculatorParamsService(
        for chainId: ChainModel.Id
    ) -> RewardCalculatorParamsServiceProtocol
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

    private func createRelaychainParamService(
        for chainId: ChainModel.Id
    ) -> RewardCalculatorParamsServiceProtocol {
        switch chainId {
        case KnowChainId.vara:
            VaraRewardParamsService(
                connection: connection,
                runtimeCodingService: runtimeService,
                operationQueue: operationQueue
            )
        case KnowChainId.polkadot:
            PolkadotRewardParamsService(
                connection: connection,
                runtimeCodingService: runtimeService,
                stateCallFactory: StateCallRequestFactory(),
                operationQueue: operationQueue
            )
        default:
            InflationRewardCalculatorParamsService(
                connection: connection,
                runtimeService: runtimeService,
                operationQueue: operationQueue
            )
        }
    }
}

extension RewardCalculatorParamsServiceFactory: RewardCalculatorParamsServiceFactoryProtocol {
    func createRewardCalculatorParamsService(
        for chainId: ChainModel.Id
    ) -> RewardCalculatorParamsServiceProtocol {
        switch stakingType {
        case .relaychain, .nominationPools:
            return createRelaychainParamService(for: chainId)
        default:
            return NoRewardCalculatorParamsService()
        }
    }
}
