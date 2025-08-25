import Foundation
import Operation_iOS

final class ChainRegistryRuntimeCodingServiceProvider {
    private let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

// MARK: - RuntimeCodingServiceProviderProtocol

extension ChainRegistryRuntimeCodingServiceProvider: RuntimeCodingServiceProviderProtocol {
    func createRuntimeCodingServiceWrapper(
        for chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<RuntimeCodingServiceProtocol> {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            return .createWithError(
                RuntimeCodingServiceProviderError.runtimeMetadaUnavailable(chainId: chainId)
            )
        }

        return .createWithResult(runtimeProvider)
    }
}
