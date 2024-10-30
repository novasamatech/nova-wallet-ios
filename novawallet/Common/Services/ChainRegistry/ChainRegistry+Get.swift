import Foundation

extension ChainRegistryProtocol {
    func getConnectionOrError(for chainId: ChainModel.Id) throws -> ChainConnection {
        guard let connection = getConnection(for: chainId) else {
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
}
