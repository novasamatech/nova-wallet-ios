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

            let thresholdType: TimepointThresholdType = .block(
                blockNumber: params.currentBlockNumber,
                blockTime: blockTime
            )
            let threshold = TimepointThreshold(type: thresholdType)
                .backIn(seconds: TimeInterval(params.lastVotedDays).secondsFromDays)

            return self.fetchDelegateListWrapper(for: threshold)
        }

        wrapper.addDependency(wrapper: blockTimeUpdateWrapper)

        let dependencies = blockTimeUpdateWrapper.allOperations + wrapper.dependencies

        return .init(targetOperation: wrapper.targetOperation, dependencies: dependencies)
    }
}
