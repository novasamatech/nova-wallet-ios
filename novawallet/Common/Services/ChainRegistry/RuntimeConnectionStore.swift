import Foundation
import SubstrateSdk

protocol RuntimeConnectionStoring {
    func getConnection() throws -> JSONRPCEngine
    func getRuntimeProvider() throws -> RuntimeProviderProtocol
}

struct ChainRegistryRuntimeConnectionStore {
    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
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
}

extension StaticRuntimeConnectionStore: RuntimeConnectionStoring {
    func getConnection() throws -> JSONRPCEngine {
        connection
    }

    func getRuntimeProvider() throws -> RuntimeProviderProtocol {
        runtimeProvider
    }
}
