import Foundation
import Operation_iOS

final class TransactionHistoryHybridFetcher {
    let remoteOperationFactory: WalletRemoteHistoryFactoryProtocol
    let repository: AnyDataProviderRepository<TransactionHistoryItem>
    let accountId: AccountId
    let chainAsset: ChainAsset
    let pageSize: Int
    let operationQueue: OperationQueue

    private let localFetcher: TransactionHistoryFetching

    @Atomic(defaultValue: nil) private var remoteFetcher: TransactionHistoryFetching?
    @Atomic(defaultValue: nil) private var syncService: TransactionHistorySyncService?

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        remoteOperationFactory: WalletRemoteHistoryFactoryProtocol,
        repository: AnyDataProviderRepository<TransactionHistoryItem>,
        provider: StreamableProvider<TransactionHistoryItem>,
        operationQueue: OperationQueue,
        pageSize: Int
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.remoteOperationFactory = remoteOperationFactory
        self.repository = repository
        localFetcher = TransactionHistoryLocalFetcher(provider: provider)
        self.operationQueue = operationQueue
        self.pageSize = pageSize
    }

    private func createRemoteFetcher(from result: WalletRemoteHistoryData) {
        remoteFetcher = TransactionHistoryRemoteFetcher(
            accountId: accountId,
            chainAsset: chainAsset,
            operationFactory: remoteOperationFactory,
            operationQueue: operationQueue,
            pageSize: pageSize,
            initPagination: .init(count: pageSize, context: result.context)
        )

        remoteFetcher?.delegate = localFetcher.delegate
    }
}

extension TransactionHistoryHybridFetcher: TransactionHistoryFetching {
    var delegate: TransactionHistoryFetcherDelegate? {
        get {
            localFetcher.delegate
        }

        set {
            localFetcher.delegate = newValue
            remoteFetcher?.delegate = newValue
        }
    }

    var isComplete: Bool {
        remoteFetcher?.isComplete ?? false
    }

    var isFetching: Bool {
        remoteFetcher?.isFetching ?? syncService?.isSyncing ?? false
    }

    func start() {
        guard remoteFetcher == nil, syncService == nil else {
            return
        }

        localFetcher.start()

        syncService = TransactionHistorySyncService(
            chainAsset: chainAsset,
            accountId: accountId,
            remoteOperationFactory: remoteOperationFactory,
            repository: repository,
            pageSize: pageSize,
            operationQueue: operationQueue
        ) { [weak self] result in
            self?.syncService = nil
            self?.createRemoteFetcher(from: result)
            DispatchQueue.main.async {
                self?.delegate?.didUpdateFetchingState()
            }
        }

        syncService?.setup()
    }

    func fetchNext() {
        remoteFetcher?.fetchNext()
    }
}
