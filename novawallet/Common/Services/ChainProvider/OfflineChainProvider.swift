import Foundation
import Operation_iOS

final class OfflineChainProvider {
    private let repository: AnyDataProviderRepository<ChainModel>

    init(repository: AnyDataProviderRepository<ChainModel>) {
        self.repository = repository
    }
}

// MARK: - ChainProviderProtocol

extension OfflineChainProvider: ChainProviderProtocol {
    func createChainWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<ChainModel> {
        let fetchOperation = repository.fetchOperation(
            by: chainId,
            options: .init()
        )
        let resultOepration = ClosureOperation<ChainModel> {
            guard let chain = try fetchOperation.extractNoCancellableResultData() else {
                throw ChainProviderError.chainNotFound(chainId: chainId)
            }

            return chain
        }

        resultOepration.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOepration,
            dependencies: [fetchOperation]
        )
    }
}
