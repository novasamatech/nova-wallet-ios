import Foundation
import SubstrateSdk

protocol DelegatedAccountSourceFactoryProtocol {
    func createSources(for blockHash: Data?) -> [DelegatedAccountsRepositoryProtocol]
}

class DelegatedAccountSourcesFactory {
    private let chain: ChainModel
    private let chainRegistry: ChainRegistryProtocol
    private let requestFactory: StorageRequestFactoryProtocol

    init(
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        requestFactory: StorageRequestFactoryProtocol
    ) {
        self.chain = chain
        self.chainRegistry = chainRegistry
        self.requestFactory = requestFactory
    }
}

// MARK: - DelegatedAccountSourceFactoryProtocol

extension DelegatedAccountSourcesFactory: DelegatedAccountSourceFactoryProtocol {
    func createSources(for blockHash: Data?) -> [DelegatedAccountsRepositoryProtocol] {
        var sources: [DelegatedAccountsRepositoryProtocol] = []

        let chainId = chain.chainId

        if
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId) {
            let proxyRepository = ChainProxyAccountsRepository(
                requestFactory: requestFactory,
                connection: connection,
                runtimeProvider: runtimeProvider,
                blockHash: blockHash
            )
            sources.append(proxyRepository)
        }

        let multisigRepository = MultisigAccountsRepository(chain: chain)
        sources.append(multisigRepository)

        return sources
    }
}
