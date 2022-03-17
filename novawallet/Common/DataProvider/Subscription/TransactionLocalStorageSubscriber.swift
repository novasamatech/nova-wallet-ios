import Foundation
import RobinHood

protocol TransactionLocalStorageSubscriber: AnyObject {
    var transactionLocalSubscriptionFactory: TransactionLocalSubscriptionFactoryProtocol { get }

    var transactionLocalSubscriptionHandler: TransactionLocalSubscriptionHandler { get }

    func subscribeToTransaction(
        for txId: String,
        chainId: ChainModel.Id
    ) -> StreamableProvider<TransactionHistoryItem>
}

extension TransactionLocalStorageSubscriber {
    func subscribeToTransaction(
        for txId: String,
        chainId: ChainModel.Id
    ) -> StreamableProvider<TransactionHistoryItem> {
        let provider = transactionLocalSubscriptionFactory.getTransactionsProviderById(
            txId,
            chainId: chainId
        )

        let updateClosure = {
            [weak self] (changes: [DataProviderChange<TransactionHistoryItem>]) in
            self?.transactionLocalSubscriptionHandler.handleTransactions(
                result: .success(changes)
            )
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.transactionLocalSubscriptionHandler.handleTransactions(
                result: .failure(error)
            )
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: true
        )

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return provider
    }
}

extension TransactionLocalStorageSubscriber where Self: TransactionLocalSubscriptionHandler {
    var transactionLocalSubscriptionHandler: TransactionLocalSubscriptionHandler { self }
}
