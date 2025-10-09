import UIKit
import UIKit_iOS
import Operation_iOS

final class TransactionHistoryInteractor: AnyCancellableCleaning, AnyProviderAutoCleaning {
    weak var presenter: TransactionHistoryInteractorOutputProtocol?

    let fetcherFactory: TransactionHistoryFetcherFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let chainAsset: ChainAsset
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let localFilterFactory: TransactionHistoryLocalFilterFactoryProtocol
    let ahmInfoFactory: AHMFullInfoFactoryProtocol
    let metaAccount: MetaAccountModel
    let accountId: AccountId
    let pageSize: Int
    let operationQueue: OperationQueue

    private var fetcher: TransactionHistoryFetching?
    private var priceProvider: AnySingleValueProvider<PriceHistory>?

    private var localFilterCancellable: CancellableCall?

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        metaAccount: MetaAccountModel,
        fetcherFactory: TransactionHistoryFetcherFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        localFilterFactory: TransactionHistoryLocalFilterFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        ahmInfoFactory: AHMFullInfoFactoryProtocol,
        operationQueue: OperationQueue,
        pageSize: Int
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.fetcherFactory = fetcherFactory
        self.chainRegistry = chainRegistry
        self.localFilterFactory = localFilterFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.pageSize = pageSize
        self.metaAccount = metaAccount
        self.ahmInfoFactory = ahmInfoFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        clear(cancellable: &localFilterCancellable)
    }
}

// MARK: - Private

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

    func setupPriceHistorySubscription() {
        guard let priceId = chainAsset.asset.priceId else {
            priceProvider = nil
            return
        }

        clear(singleValueProvider: &priceProvider)

        priceProvider = subscribeToPriceHistory(for: priceId, currency: selectedCurrency)
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

    func checkIfHasRelayChainAccount(relayChainId: ChainModel.Id) -> Bool {
        guard let chain = chainRegistry.getChain(for: relayChainId) else {
            return false
        }

        let chainAccountRequest = chain.accountRequest()

        return metaAccount.fetch(for: chainAccountRequest) != nil
    }

    func provideAHMInfo() {
        guard
            let parentChainId = chainAsset.chain.parentId,
            checkIfHasRelayChainAccount(relayChainId: parentChainId)
        else {
            return
        }

        let wrapper = ahmInfoFactory.fetch(by: parentChainId)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(fullInfo):
                guard
                    let fullInfo,
                    fullInfo.destinationChain.chainId == self?.chainAsset.chain.chainId
                else { return }

                self?.presenter?.didReceive(ahmFullInfo: fullInfo)
            case let .failure(error):
                self?.presenter?.didReceive(error: .fetchFailed(error))
            }
        }
    }
}

// MARK: - TransactionHistoryInteractorInputProtocol

extension TransactionHistoryInteractor: TransactionHistoryInteractorInputProtocol {
    func loadNext() {
        guard let fetcher = fetcher, !fetcher.isFetching, !fetcher.isComplete else {
            presenter?.didReceive(changes: [])
            return
        }

        fetcher.fetchNext()
    }

    func setup() {
        provideAHMInfo()
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

// MARK: - PriceLocalStorageSubscriber

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

// MARK: - TransactionHistoryFetcherDelegate

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

// MARK: - SelectedCurrencyDepending

extension TransactionHistoryInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil {
            setupPriceHistorySubscription()
        }
    }
}
