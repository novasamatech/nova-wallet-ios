import Foundation
import RobinHood

enum TransactionHistoryFetcherError {
    case remoteFetchFailed(Error)
}

protocol TransactionHistoryFetcherDelegate: AnyObject {
    func didReceiveHistoryChanges(
        _ fetcher: TransactionHistoryFetching,
        changes: [DataProviderChange<TransactionHistoryItem>]
    )

    func didReceiveHistoryError(_ error: TransactionHistoryFetcherError)
}

protocol TransactionHistoryFetching: AnyObject {
    var delegate: TransactionHistoryFetcherDelegate { get set }

    var isComplete: Bool { get }

    var isFetching: Bool { get }

    func start()

    func fetchNext()
}
