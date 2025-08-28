import Foundation
import SubstrateSdk

protocol RuntimeConnectionStoring {
    func getConnection() throws -> JSONRPCEngine
    func getRuntimeProvider() throws -> RuntimeProviderProtocol
}

struct ChainRegistryRuntimeConnectionStore {
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol

    init(chainId: ChainModel.Id, chainRegistry: ChainRegistryProtocol) {
        self.chainId = chainId
        self.chainRegistry = chainRegistry
    }
}

extension ChainRegistryRuntimeConnectionStore: RuntimeConnectionStoring {
    func getConnection() throws -> JSONRPCEngine {
        try chainRegistry.getConnectionOrError(for: chainId)
    }

    func getRuntimeProvider() throws -> RuntimeProviderProtocol {
        try chainRegistry.getRuntimeProviderOrError(for: chainId)
    }
}

struct StaticRuntimeConnectionStore {
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol

    init(connection: JSONRPCEngine, runtimeProvider: RuntimeProviderProtocol) {
        self.connection = connection
        self.runtimeProvider = runtimeProvider
    }
}

extension StaticRuntimeConnectionStore: RuntimeConnectionStoring {
    func getConnection() throws -> JSONRPCEngine {
        connection
    }

    func getRuntimeProvider() throws -> RuntimeProviderProtocol {
        runtimeProvider
    }
}
