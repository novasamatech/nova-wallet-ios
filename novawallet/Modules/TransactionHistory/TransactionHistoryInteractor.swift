import UIKit
import SoraUI
import RobinHood
import CommonWallet

final class TransactionHistoryInteractor {
    weak var presenter: TransactionHistoryInteractorOutputProtocol?

    let fetcherFactory: TransactionHistoryFetcherFactoryProtocol
    let chainAsset: ChainAsset
    let accountId: AccountId
    let pageSize: Int

    private var fetcher: TransactionHistoryFetching?

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        fetcherFactory: TransactionHistoryFetcherFactoryProtocol,
        pageSize: Int
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.fetcherFactory = fetcherFactory
        self.pageSize = pageSize
    }

    private func setupFetcher(for filter: WalletHistoryFilter) {
        do {
            fetcher = try fetcherFactory.createFetcher(
                for: accountId,
                chainAsset: chainAsset,
                pageSize: pageSize,
                filter: filter
            )

            fetcher?.delegate = self

            fetcher?.start()
        } catch {
            presenter?.didReceive(error: .setupFailed(error))
        }
    }
}

extension TransactionHistoryInteractor: TransactionHistoryInteractorInputProtocol {
    func loadNext() {
        guard let fetcher = fetcher, !fetcher.isFetching, !fetcher.isComplete else {
            presenter?.didReceive(changes: [])
            return
        }

        fetcher.fetchNext()
    }

    func setup() {
        setupFetcher(for: .all)
    }

    func set(filter: WalletHistoryFilter) {
        setupFetcher(for: filter)
    }
}

extension TransactionHistoryInteractor: TransactionHistoryFetcherDelegate {
    func didReceiveHistoryChanges(
        _: TransactionHistoryFetching,
        changes: [DataProviderChange<TransactionHistoryItem>]
    ) {
        presenter?.didReceive(changes: changes)
    }

    func didReceiveHistoryError(_: TransactionHistoryFetching, error: TransactionHistoryFetcherError) {
        presenter?.didReceive(error: .fetchFailed(error))
    }
}
