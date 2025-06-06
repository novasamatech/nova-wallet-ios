import Foundation
import SubstrateSdk

protocol DelegatedAccountSourceFactoryProtocol {
    func createSource(for blockHash: Data?) -> DelegatedAccountsAggregatorProtocol
}

class DelegatedAccountSourceFactory {
    private let chain: ChainModel
    private let chainRegistry: ChainRegistryProtocol
    private let requestFactory: StorageRequestFactoryProtocol
    private let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        requestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.chainRegistry = chainRegistry
        self.requestFactory = requestFactory
        self.operationQueue = operationQueue
    }
}

// MARK: - DelegatedAccountSourceFactoryProtocol

extension DelegatedAccountSourceFactory: DelegatedAccountSourceFactoryProtocol {
    func createSource(for blockHash: Data?) -> DelegatedAccountsAggregatorProtocol {
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

        let repository = DelegatedAccountsRepository(
            sources: sources,
            operationQueue: operationQueue
        )

        return repository
    }
}
