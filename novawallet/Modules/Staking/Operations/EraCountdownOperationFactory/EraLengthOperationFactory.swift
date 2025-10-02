import Foundation
import Operation_iOS

protocol EraLengthOperationFactoryProtocol {
    func createEraLengthWrapper(
        for chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<SessionIndex>
}

final class EraLengthOperationFactory {
    let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

extension EraLengthOperationFactory: EraLengthOperationFactoryProtocol {
    func createEraLengthWrapper(
        for chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<SessionIndex> {
        do {
            let chain = try chainRegistry.getChainOrError(for: chainId)

            if let sessionsPerEra = chain.sessionsPerEra {
                return .createWithResult(sessionsPerEra)
            }

            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

            return PrimitiveConstantOperation.wrapper(for: Staking.eraLengthPath, runtimeService: runtimeService)
        } catch {
            return .createWithError(error)
        }
    }
}
