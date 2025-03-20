import UIKit
import SoraUI
import Operation_iOS

final class TransactionHistoryInteractor: AnyCancellableCleaning {
    weak var presenter: TransactionHistoryInteractorOutputProtocol?

    let fetcherFactory: TransactionHistoryFetcherFactoryProtocol
    let chainAsset: ChainAsset
    let priceHistoryOperationFactory: PriceChartDataOperationFactoryProtocol
    let localFilterFactory: TransactionHistoryLocalFilterFactoryProtocol
    let accountId: AccountId
    let pageSize: Int
    let operationQueue: OperationQueue

    private var fetcher: TransactionHistoryFetching?

    private var localFilterCancellable: CancellableCall?

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        fetcherFactory: TransactionHistoryFetcherFactoryProtocol,
        localFilterFactory: TransactionHistoryLocalFilterFactoryProtocol,
        priceHistoryOperationFactory: PriceChartDataOperationFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        pageSize: Int
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.fetcherFactory = fetcherFactory
        self.localFilterFactory = localFilterFactory
        self.priceHistoryOperationFactory = priceHistoryOperationFactory
        self.pageSize = pageSize
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        clear(cancellable: &localFilterCancellable)
    }
}

// MARK: Private

private extension TransactionHistoryInteractor {
    func setupFetcher(for filter: WalletHistoryFilter) {
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

    func fetchHistoricalPrices() {
        guard let priceId = chainAsset.asset.priceId else {
            return
        }

        let wrapper = priceHistoryOperationFactory.createWrapper(
            tokenId: priceId,
            currency: selectedCurrency
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(historyByPeriod):
                guard let history = historyByPeriod[.allTime] else { return }

                let calculator = TokenPriceCalculator(history: history)
                self?.presenter?.didReceive(priceCalculator: calculator)
            case let .failure(error):
                self?.presenter?.didReceive(error: .priceFailed(error))
            }
        }
    }

    func provideLocalFilter() {
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

// MARK: TransactionHistoryInteractorInputProtocol

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
        fetchHistoricalPrices()
        setupFetcher(for: .all)
    }

    func refetchPrices() {
        fetchHistoricalPrices()
    }

    func retryLocalFilter() {
        provideLocalFilter()
    }

    func set(filter: WalletHistoryFilter) {
        setupFetcher(for: filter)
    }
}

// MARK: TransactionHistoryFetcherDelegate

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

// MARK: SelectedCurrencyDepending

extension TransactionHistoryInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil {
            fetchHistoricalPrices()
        }
    }
}
