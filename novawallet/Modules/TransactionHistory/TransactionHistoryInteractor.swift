import UIKit
import SoraUI
import RobinHood
import CommonWallet

final class TransactionHistoryInteractor {
    weak var presenter: TransactionHistoryInteractorOutputProtocol?

    let fetcherFactory: TransactionHistoryFetcherFactoryProtocol
    let chainAsset: ChainAsset
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let accountId: AccountId
    let pageSize: Int

    private var fetcher: TransactionHistoryFetching?
    private var priceProvider: AnySingleValueProvider<PriceHistory>?

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        fetcherFactory: TransactionHistoryFetcherFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        pageSize: Int
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.fetcherFactory = fetcherFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.pageSize = pageSize
        self.currencyManager = currencyManager
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

    private func setupPriceHistorySubscription() {
        guard let priceId = chainAsset.asset.priceId else {
            priceProvider = nil
            return
        }

        priceProvider = subscribeToPriceHistory(for: priceId, currency: selectedCurrency)
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
        setupPriceHistorySubscription()
        setupFetcher(for: .all)
    }

    func set(filter: WalletHistoryFilter) {
        setupFetcher(for: filter)
    }
}

extension TransactionHistoryInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePriceHistory(
        result: Result<PriceHistory?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(optHistory):
            if let history = optHistory {
                let calculator = TokenPriceCalculator(history: history)
                presenter?.didReceive(priceCalculator: calculator)
            }

        case let .failure(error):
            presenter?.didReceive(error: .priceFailed(error))
        }
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

extension TransactionHistoryInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil {
            setupPriceHistorySubscription()
        }
    }
}
