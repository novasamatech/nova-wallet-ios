import Foundation
import SubstrateSdk
import Operation_iOS

struct GovernanceDelegateListBlockParams {
    let currentBlockNumber: BlockNumber
    let lastVotedDays: Int
    let timelineService: ChainTimelineFacadeProtocol
}

extension GovernanceDelegateListFactoryProtocol {
    func fetchDelegateListByBlockNumber(
        _ params: GovernanceDelegateListBlockParams,
        operationManager: OperationManagerProtocol
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]?> {
        let blockTimeUpdateWrapper = params.timelineService.createBlockTimeOperation()

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
                for: .block(blockNumber: activityBlockNumber, blockTime: blockTime)
            )
        }

        wrapper.addDependency(wrapper: blockTimeUpdateWrapper)

        let dependencies = blockTimeUpdateWrapper.allOperations + wrapper.dependencies

        return .init(targetOperation: wrapper.targetOperation, dependencies: dependencies)
    }
}
