import Foundation
import RobinHood

final class TransactionHistoryLocalFetcher {
    let provider: StreamableProvider<TransactionHistoryItem>

    weak var delegate: TransactionHistoryFetcherDelegate?

    init(provider: StreamableProvider<TransactionHistoryItem>) {
        self.provider = provider
    }
}

extension TransactionHistoryLocalFetcher: TransactionHistoryFetching {
    var isComplete: Bool {
        true
    }

    var isFetching: Bool {
        false
    }

    func start() {
        provider.removeObserver(self)

        let updateClosure: ([DataProviderChange<TransactionHistoryItem>]) -> Void = { [weak self] changes in
            guard let strongSelf = self else {
                return
            }

            strongSelf.delegate?.didReceiveHistoryChanges(strongSelf, changes: changes)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            guard let strongSelf = self else {
                return
            }

            strongSelf.delegate?.didReceiveHistoryError(strongSelf, error: .remoteFetchFailed(error))
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
        )

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func fetchNext() {}
}
