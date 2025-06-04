import Foundation
import SubstrateSdk

extension ChainRegistryProtocol {
    func getConnectionOrError(for chainId: ChainModel.Id) throws -> ChainConnection {
        guard let connection = getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        return connection
    }

    func getOneShotConnectionOrError(for chainId: ChainModel.Id) throws -> JSONRPCEngine {
        guard let connection = getOneShotConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        return connection
    }

    func getRuntimeProviderOrError(for chainId: ChainModel.Id) throws -> RuntimeProviderProtocol {
        guard let runtimeProvider = getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        return runtimeProvider
    }

    func getChainOrError(for chainId: ChainModel.Id) throws -> ChainModel {
        guard let chain = getChain(for: chainId) else {
            throw ChainRegistryError.noChain(chainId)
        }

        return chain
    }
}
