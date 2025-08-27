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
    func createSource(for _: Data?) -> DelegatedAccountsAggregatorProtocol {
        // TODO: Receive it from remote config as staking
        let proxyRepository = DiscoverProxiesAccountsRepository(
            url: ApplicationConfig.shared.multichainDelegationIndexer
        )

        let multisigRepository = MultisigAccountsRepository(chain: chain)

        let repository = DelegatedAccountsAggregator(
            sources: [proxyRepository, multisigRepository],
            operationQueue: operationQueue
        )

        return repository
    }
}
