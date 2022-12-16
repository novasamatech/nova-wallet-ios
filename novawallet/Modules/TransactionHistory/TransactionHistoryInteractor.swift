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

    private var dataProvider: StreamableProvider<TransactionHistoryItem>?
    private var count = 100
    private var offset = 0

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
            if self.offset == 0 {
                self.offset = 1
            }
        }

        let failBlock: (Error) -> Void = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
        }

        dataProvider = try? dataProviderFactory.getTransactionsProvider(
            address: accountAddress,
            chainAsset: chainAsset,
            historyFilter: historyFilter
        )

        dataProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: changesBlock,
            failing: failBlock,
            options: .init(alwaysNotifyOnRefresh: true)
        )
    }

    private func clearDataProvider() {
        dataProvider?.removeObserver(self)
    }

    var currentFetchOpeartion: CancellableCall?
}

extension TransactionHistoryInteractor: TransactionHistoryInteractorInputProtocol {
    func loadNext() {
        guard currentFetchOpeartion == nil, offset > 0 else {
            return
        }
        offset += 1
        DispatchQueue.global().async {
            self.currentFetchOpeartion = self.dataProvider?.fetch(
                offset: self.offset,
                count: self.count,
                synchronized: false,
                with: { [weak self] result in
                    DispatchQueue.main.async {
                        self?.currentFetchOpeartion = nil
                        switch result {
                        case let .failure(error):
                            self?.presenter.didReceive(error: error)
                        case let .success(items):
                            self?.presenter.didReceive(changes: items.map { DataProviderChange.insert(newItem: $0) })
                        case .none:
                            break
                        }
                    }
                }
            )
        }
    }

    func setup(historyFilter: WalletHistoryFilter) {
        guard historyFilter != self.historyFilter else {
            return
        }
        clearDataProvider()
        setupDataProvider(historyFilter: historyFilter)
        dataProvider?.refresh()
    }

    func refresh() {}

    func loadNext(
        for _: WalletHistoryRequest,
        pagination _: Pagination
    ) {
        guard currentFetchOpeartion == nil else {
            return
        }

//        let fetch = fetchTransactionHistory(
//            for: filter,
//            pagination: pagination,
//            runCompletionIn: .main
//        ) { [weak self] optionalResult in
//            guard let self = self else {
//                return
//            }
//
//            if let result = optionalResult {
//                switch result {
//                case let .success(pageData):
//                    let loadedData = pageData ?? AssetTransactionPageData(transactions: [])
//                    self.presenter.didReceive(transactionData: loadedData, for: pagination)
//                case let .failure(error):
//                    self.presenter.didReceive(error: error, for: pagination)
//                }
//            }
//            self.currentFetchOpeartion = nil
//        }
//
//        currentFetchOpeartion = fetch
    }
}
