import Foundation
import Operation_iOS

protocol ChainTimelineFacadeProtocol {
    var timelineChainId: ChainModel.Id { get }

    func createBlockTimeOperation() -> CompoundOperationWrapper<BlockTime>
    func createTimepointThreshold(backIn days: Int) -> CompoundOperationWrapper<TimepointThreshold?>
}

final class ChainTimelineFacade {
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let estimationService: BlockTimeEstimationServiceProtocol

    var timelineChainId: ChainModel.Id {
        chainRegistry.getChain(for: chainId)?.timelineChain ?? chainId
    }

    init(
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        estimationService: BlockTimeEstimationServiceProtocol
    ) {
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.estimationService = estimationService
    }
}

extension ChainTimelineFacade: ChainTimelineFacadeProtocol {
    func createBlockTimeOperation() -> CompoundOperationWrapper<BlockTime> {
        do {
            let timelineChain = try chainRegistry.getChainOrError(for: timelineChainId)
            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: timelineChainId)

            return BlockTimeOperationFactory(chain: timelineChain).createBlockTimeOperation(
                from: runtimeService,
                blockTimeEstimationService: estimationService
            )
        } catch {
            return .createWithError(error)
        }
    }

    func createTimepointThreshold(backIn days: Int) -> CompoundOperationWrapper<TimepointThreshold?> {
        if chainId != timelineChainId {
            let timestamp = Date().addingTimeInterval(-(.secondsInDay * Double(days))).timeIntervalSince1970

            return .createWithResult(.timestamp(Int64(timestamp)))
        } else {
            let blockTimeWrapper = createBlockTimeOperation()

            let blockInDaysOperation = ClosureOperation<TimepointThreshold?> { [weak self] in
                guard let self else { throw BaseOperationError.parentOperationCancelled }

                let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()

                let activityBlockNumber = estimationService.currentBlockNumber?.blockBackInDays(
                    days,
                    blockTime: blockTime
                )

                guard let activityBlockNumber else { return nil }

                return .blockNumber(activityBlockNumber)
            }

            blockInDaysOperation.addDependency(blockTimeWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: blockInDaysOperation,
                dependencies: blockTimeWrapper.allOperations
            )
        }
    }
}
