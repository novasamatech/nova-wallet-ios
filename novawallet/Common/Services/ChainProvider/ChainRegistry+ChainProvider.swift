import Foundation
import Operation_iOS

extension ChainRegistry: ChainProviderProtocol {
    func createChainWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<ChainModel> {
        do {
            return .createWithResult(try getChainOrError(for: chainId))
        } catch {
            return .createWithError(error)
        }
    }
}
