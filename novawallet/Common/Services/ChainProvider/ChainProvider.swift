import Foundation
import Operation_iOS

protocol ChainProviderProtocol {
    func createChainWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<ChainModel>
}

enum ChainProviderError: Error {
    case chainNotFound(chainId: ChainModel.Id)
}
