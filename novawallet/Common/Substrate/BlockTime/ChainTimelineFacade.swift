import Foundation
import Operation_iOS

protocol ChainTimelineFacadeProtocol {
    var timelineChainId: ChainModel.Id { get }

    func createBlockTimeOperation() -> CompoundOperationWrapper<BlockTime>
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
}
