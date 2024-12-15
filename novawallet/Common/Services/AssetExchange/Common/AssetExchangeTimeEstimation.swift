import Foundation
import Operation_iOS

protocol AssetExchangeTimeEstimating {
    func totalTimeWrapper(for chainIds: [ChainModel.Id]) -> CompoundOperationWrapper<TimeInterval>
}

final class AssetExchangeTimeEstimator {
    let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

extension AssetExchangeTimeEstimator: AssetExchangeTimeEstimating {
    func totalTimeWrapper(for chainIds: [ChainModel.Id]) -> CompoundOperationWrapper<TimeInterval> {
        do {
            let wrappers: [CompoundOperationWrapper<BlockTime>] = try chainIds.compactMap { chainId in
                guard
                    let chain = chainRegistry.getChain(for: chainId),
                    let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
                    throw ChainRegistryError.runtimeMetadaUnavailable
                }

                let operationFactory = BlockTimeOperationFactory(chain: chain)

                return operationFactory.createExpectedBlockTimeWrapper(from: runtimeProvider)
            }

            let mappingOperation = ClosureOperation<TimeInterval> {
                let blockTime: BlockTime = try wrappers
                    .map { try $0.targetOperation.extractNoCancellableResultData() }
                    .reduce(0) { $0 + $1 }

                return TimeInterval(blockTime).seconds
            }

            wrappers.forEach { mappingOperation.addDependency($0.targetOperation) }

            let dependecies = wrappers.flatMap(\.allOperations)

            return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependecies)
        } catch {
            return .createWithError(error)
        }
    }
}
