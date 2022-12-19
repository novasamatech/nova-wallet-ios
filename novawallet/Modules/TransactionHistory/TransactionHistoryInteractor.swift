import UIKit
import SoraUI
import RobinHood
import CommonWallet

final class TransactionHistoryInteractor {
    weak var presenter: TransactionHistoryInteractorOutputProtocol!
    let historyFacade: AssetHistoryFactoryFacadeProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let dataProviderFactory: TransactionSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let chainAsset: ChainAsset
    let metaAccount: MetaAccountModel

    private var historyFilter: WalletHistoryFilter?
    private var accountAddress: AccountAddress? {
        metaAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    private var currentFetchOpeartion: CancellableCall?
    private let fetchCount: Int = 100
    private var currentOffset: Int = 0

    private var localDataProvider: StreamableProvider<TransactionHistoryItem>?
    private var remoteDataProvider: StreamableProvider<TransactionHistoryItem>?

    init(
        chainAsset: ChainAsset,
        metaAccount: MetaAccountModel,
        operationQueue: OperationQueue,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        historyFacade: AssetHistoryFactoryFacadeProtocol,
        dataProviderFactory: TransactionSubscriptionFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.metaAccount = metaAccount
        self.operationQueue = operationQueue
        self.repositoryFactory = repositoryFactory
        self.historyFacade = historyFacade
        self.dataProviderFactory = dataProviderFactory
    }

    private func setupDataProvider(historyFilter: WalletHistoryFilter) {
        guard let accountAddress = accountAddress else {
            return
        }
        let changesBlock = { [weak self] (changes: [DataProviderChange<TransactionHistoryItem>]) -> Void in
            guard let self = self else {
                return
            }
            self.presenter.didReceive(changes: changes)
            if self.currentOffset == 0 {
                self.currentOffset = 1
            }
        }

        let failBlock: (Error) -> Void = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: .dataProvider(error))
        }

        let transactionsProvider = try? dataProviderFactory.getTransactionsProvider(
            address: accountAddress,
            chainAsset: chainAsset,
            historyFilter: historyFilter
        )

        localDataProvider = transactionsProvider?.local

        localDataProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: changesBlock,
            failing: failBlock,
            options: .init(alwaysNotifyOnRefresh: true)
        )

        remoteDataProvider = transactionsProvider?.remote
    }

    private func clearDataProvider() {
        localDataProvider?.removeObserver(self)
    }
}

extension TransactionHistoryInteractor: TransactionHistoryInteractorInputProtocol {
    func refresh() {}

    func loadNext() {
        guard currentFetchOpeartion == nil, currentOffset > 0 else {
            presenter.didReceive(error: .loadingInProgress)
            return
        }

        currentFetchOpeartion = remoteDataProvider?.fetch(
            offset: currentOffset,
            count: fetchCount,
            synchronized: false,
            with: { [weak self] result in
                DispatchQueue.main.async {
                    self?.currentFetchOpeartion = nil
                    switch result {
                    case let .failure(error):
                        self?.presenter.didReceive(error: .fetchProvider(error))
                    case let .success(items):
                        self?.presenter.didReceive(nextItems: items)
                        if !items.isEmpty {
                            self?.currentOffset += 1
                        }
                    case .none:
                        break
                    }
                }
            }
        )
    }

    func setup(historyFilter: WalletHistoryFilter) {
        guard historyFilter != self.historyFilter else {
            return
        }
        accountAddress.map {
            presenter.didReceive(accountAddress: $0)
        }
        clearDataProvider()
        setupDataProvider(historyFilter: historyFilter)
        localDataProvider?.refresh()
    }
}
