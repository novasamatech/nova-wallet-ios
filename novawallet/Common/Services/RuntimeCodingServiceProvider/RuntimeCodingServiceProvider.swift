import Foundation
import Operation_iOS

protocol RuntimeCodingServiceProviderProtocol {
    func createRuntimeCodingServiceWrapper(
        for chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<RuntimeCodingServiceProtocol>
}

enum RuntimeCodingServiceProviderError: Error {
    case runtimeMetadaUnavailable(chainId: ChainModel.Id)
}
