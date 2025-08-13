import Foundation
import Operation_iOS

extension ChainRegistry: RuntimeCodingServiceProviderProtocol {
    func createRuntimeCodingServiceWrapper(
        for chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<RuntimeCodingServiceProtocol> {
        guard let runtimeProvider = getRuntimeProvider(for: chainId) else {
            return .createWithError(
                RuntimeCodingServiceProviderError.runtimeMetadaUnavailable(chainId: chainId)
            )
        }

        return .createWithResult(runtimeProvider)
    }
}
