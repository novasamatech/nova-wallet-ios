import UIKit
import SoraUI
import RobinHood
import CommonWallet

final class TransactionHistoryInteractor {
    weak var presenter: TransactionHistoryInteractorOutputProtocol?
    let historyFacade: AssetHistoryFactoryFacadeProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let dataProviderFactory: TransactionSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let chainAsset: ChainAsset
    let metaAccount: MetaAccountModel
    let fetchCount: Int

    private var historyFilter: WalletHistoryFilter?
    private var accountAddress: AccountAddress? {
        metaAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    private var currentFetchOperation: CompoundOperationWrapper<[TransactionHistoryItem]>?
    private var firstPageLoaded: Bool = false
    private var localDataProvider: StreamableProvider<TransactionHistoryItem>?
    private var remoteDataProvider: RemoteHistoryTransactionsProviderProtocol?
    private var firstPageItems: [TransactionHistoryItem] = []

    init(
        chainAsset: ChainAsset,
        metaAccount: MetaAccountModel,
        operationQueue: OperationQueue,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        historyFacade: AssetHistoryFactoryFacadeProtocol,
        dataProviderFactory: TransactionSubscriptionFactoryProtocol,
        fetchCount: Int
    ) {
        self.chainAsset = chainAsset
        self.metaAccount = metaAccount
        self.operationQueue = operationQueue
        self.repositoryFactory = repositoryFactory
        self.historyFacade = historyFacade
        self.dataProviderFactory = dataProviderFactory
        self.fetchCount = fetchCount
    }

    private func setupDataProvider() {
        guard let accountAddress = accountAddress else {
            return
        }
        let changesBlock = { [weak self] (changes: [DataProviderChange<TransactionHistoryItem>]) -> Void in
            guard let self = self else {
                return
            }
            self.firstPageLoaded = true
            self.firstPageItems = self.firstPageItems.applying(changes: changes)
            self.presenter?.didReceive(changes: changes)
        }

        let failBlock: (Error) -> Void = { [weak self] (error: Error) in
            self?.presenter?.didReceive(error: .dataProvider(error))
        }

        let transactionsProvider = try? dataProviderFactory.getTransactionsProvider(
            address: accountAddress,
            chainAsset: chainAsset
        )

        localDataProvider = transactionsProvider

        localDataProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: changesBlock,
            failing: failBlock,
            options: .init(alwaysNotifyOnRefresh: true)
        )

        remoteDataProvider = try? dataProviderFactory.getRemoteTransactionsProvider(
            address: accountAddress,
            chainAsset: chainAsset
        )
    }

    private func clearDataProvider() {
        localDataProvider?.removeObserver(self)
        localDataProvider = nil
        remoteDataProvider = nil
        currentFetchOperation?.cancel()
    }
}

extension TransactionHistoryInteractor: TransactionHistoryInteractorInputProtocol {
    func loadNext() {
        guard let remoteDataProvider = remoteDataProvider,
              currentFetchOperation == nil,
              firstPageLoaded else {
            return
        }

        guard let fetchOperation = remoteDataProvider.fetchNext(
            by: historyFilter ?? .all,
            count: fetchCount
        ) else {
            return
        }

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                do {
                    self.currentFetchOperation = nil
                    let items = try fetchOperation.targetOperation.extractNoCancellableResultData()
                    self.presenter?.didReceive(nextItems: items)
                } catch {
                    self.presenter?.didReceive(error: .fetchProvider(error))
                }
            }
        }

        currentFetchOperation = fetchOperation
        operationQueue.addOperations(
            fetchOperation.allOperations,
            waitUntilFinished: false
        )
    }

    func setup() {
        accountAddress.map { presenter?.didReceive(accountAddress: $0) }

        clearDataProvider()
        setupDataProvider()
        localDataProvider?.refresh()
    }

    func set(filter: WalletHistoryFilter) {
        guard historyFilter != filter else {
            return
        }
        historyFilter = filter

        if let fetchOperation = remoteDataProvider?.fetch(
            by: historyFilter ?? .all,
            count: fetchCount
        ) {
            fetchOperation.targetOperation.completionBlock = { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    do {
                        self.currentFetchOperation = nil
                        let items = try fetchOperation.targetOperation.extractNoCancellableResultData()
                        self.presenter?.didReceive(filteredItems: items)
                    } catch {
                        self.presenter?.didReceive(error: .filter(error))
                    }
                }
            }

            currentFetchOperation = fetchOperation
            operationQueue.addOperations(
                fetchOperation.allOperations,
                waitUntilFinished: false
            )
        } else {
            let filteredItems = firstPageItems.filter {
                filter.isFit(callPath: $0.callPath)
            }

            presenter?.didReceive(filteredItems: filteredItems)
        }
    }
}
