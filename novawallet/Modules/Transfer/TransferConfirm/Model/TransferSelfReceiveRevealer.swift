import Foundation
import Operation_iOS

final class TransferSelfReceiveRevealer {
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let visibilityWriter: AssetVisibilityWriting
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        visibilityWriter: AssetVisibilityWriting,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.accountRepositoryFactory = accountRepositoryFactory
        self.visibilityWriter = visibilityWriter
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func reveal(destination: ChainAsset, recipientAccountId: AccountId) {
        let filter = NSPredicate.filterMetaAccount(
            accountId: recipientAccountId,
            chainId: destination.chain.chainId
        )

        let repository = accountRepositoryFactory.createMetaAccountRepository(
            for: filter,
            sortDescriptors: []
        )

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        execute(
            operation: fetchOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            switch result {
            case let .success(wallets):
                self?.reveal(
                    destination: destination,
                    recipientAccountId: recipientAccountId,
                    in: wallets
                )
            case let .failure(error):
                self?.logger.error("Can't resolve the transfer recipient: \(error)")
            }
        }
    }
}

// MARK: Private

private extension TransferSelfReceiveRevealer {
    func reveal(
        destination: ChainAsset,
        recipientAccountId: AccountId,
        in wallets: [MetaAccountModel]
    ) {
        // the predicate also matches a wallet by its universal account id when a chain account overrides it
        let owners = wallets.filter {
            $0.fetch(for: destination.chain.accountRequest())?.accountId == recipientAccountId
        }

        owners.forEach { wallet in
            visibilityWriter.setState(
                metaId: wallet.metaId,
                ids: [destination.chainAssetId],
                state: .visible,
                runningCallbackIn: nil,
                completion: nil
            )
        }
    }
}
