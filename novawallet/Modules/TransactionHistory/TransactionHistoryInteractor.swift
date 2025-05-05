import UIKit
import UIKit_iOS
import Operation_iOS

final class TransactionHistoryInteractor: AnyCancellableCleaning, AnyProviderAutoCleaning {
    weak var presenter: TransactionHistoryInteractorOutputProtocol?

    let fetcherFactory: TransactionHistoryFetcherFactoryProtocol
    let chainAsset: ChainAsset
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let localFilterFactory: TransactionHistoryLocalFilterFactoryProtocol
    let accountId: AccountId
    let pageSize: Int
    let operationQueue: OperationQueue

    private var fetcher: TransactionHistoryFetching?
    private var priceProvider: AnySingleValueProvider<PriceHistory>?

    private var localFilterCancellable: CancellableCall?

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        fetcherFactory: TransactionHistoryFetcherFactoryProtocol,
        localFilterFactory: TransactionHistoryLocalFilterFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        pageSize: Int
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.fetcherFactory = fetcherFactory
        self.localFilterFactory = localFilterFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.pageSize = pageSize
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        clear(cancellable: &localFilterCancellable)
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
            presenter?.didReceiveFetchingState(isComplete: false)
        } catch {
            presenter?.didReceive(error: .setupFailed(error))
        }
    }

    private func setupPriceHistorySubscription() {
        guard let priceId = chainAsset.asset.priceId else {
            priceProvider = nil
            return
        }

        clear(singleValueProvider: &priceProvider)

        priceProvider = subscribeToPriceHistory(for: priceId, currency: selectedCurrency)
    }

    private func provideLocalFilter() {
        clear(cancellable: &localFilterCancellable)

        let wrapper = localFilterFactory.createWrapper()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.localFilterCancellable === wrapper else {
                    return
                }

                self?.localFilterCancellable = nil

                do {
                    let localFilter = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(localFilter: localFilter)
                } catch {
                    self?.presenter?.didReceive(error: .localFilter(error))
                }
            }
        }

        localFilterCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
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
        provideLocalFilter()
        setupPriceHistorySubscription()
        setupFetcher(for: .all)
    }

    func remakeSubscriptions() {
        setupPriceHistorySubscription()
    }

    func retryLocalFilter() {
        provideLocalFilter()
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

    func didUpdateFetchingState() {
        guard let fetcher = fetcher else { return }
        presenter?.didReceiveFetchingState(isComplete: !fetcher.isFetching)
    }
}

extension TransactionHistoryInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil {
            setupPriceHistorySubscription()
        }
    }
}
