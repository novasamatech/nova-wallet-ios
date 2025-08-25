import Foundation
import Operation_iOS

final class ChainRegistryChainProvider {
    private let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

// MARK: - ChainProviderProtocol

extension ChainRegistryChainProvider: ChainProviderProtocol {
    func createChainWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<ChainModel> {
        do {
            return .createWithResult(try chainRegistry.getChainOrError(for: chainId))
        } catch {
            return .createWithError(error)
        }
    }
}
