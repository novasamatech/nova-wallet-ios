import Foundation
import SubstrateSdk
import RobinHood

struct GovernanceDelegateListBlockParams {
    let currentBlockNumber: BlockNumber
    let lastVotedDays: Int
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
}

extension GovernanceDelegateListFactoryProtocol {
    func fetchDelegateListByBlockNumber(
        _ params: GovernanceDelegateListBlockParams,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]?> {
        let blockTimeUpdateWrapper = params.blockTimeOperationFactory.createBlockTimeOperation(
            from: runtimeService,
            blockTimeEstimationService: params.blockTimeService
        )

        let wrapper: CompoundOperationWrapper<[GovernanceDelegateLocal]?> = OperationCombiningService.compoundWrapper(
            operationManager: operationManager
        ) {
            let blockTime = try blockTimeUpdateWrapper.targetOperation.extractNoCancellableResultData()

            guard
                let activityBlockNumber = params.currentBlockNumber.blockBackInDays(
                    params.lastVotedDays,
                    blockTime: blockTime
                ) else {
                return nil
            }

            return self.fetchDelegateListWrapper(
                for: activityBlockNumber,
                chain: chain,
                connection: connection,
                runtimeService: runtimeService
            )
        }

        wrapper.addDependency(wrapper: blockTimeUpdateWrapper)

        let dependencies = blockTimeUpdateWrapper.allOperations + wrapper.dependencies

        return .init(targetOperation: wrapper.targetOperation, dependencies: dependencies)
    }
}
