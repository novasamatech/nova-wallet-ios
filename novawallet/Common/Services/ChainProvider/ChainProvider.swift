import Foundation
import Operation_iOS

protocol ChainProviderProtocol {
    func createChainWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<ChainModel>
}

enum ChainProviderError: Error {
    case chainNotFound(chainId: ChainModel.Id)
}

extension ChainProviderError: LocalizedError {
    var errorDescription: String? {
        localizedDescription
    }

    var localizedDescription: String {
        guard case let .chainNotFound(chainId) = self else {
            return "Unknown error"
        }

        return "Chain with id \(chainId) not found"
    }
}
