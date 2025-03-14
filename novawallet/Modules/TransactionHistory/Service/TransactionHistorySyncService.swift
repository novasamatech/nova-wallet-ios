import Foundation
import Operation_iOS

typealias TransactionSyncResultClosure = (WalletRemoteHistoryData) -> Void

final class TransactionHistorySyncService: BaseSyncService, AnyCancellableCleaning {
    let remoteOperationFactory: WalletRemoteHistoryFactoryProtocol
    let repository: AnyDataProviderRepository<TransactionHistoryItem>
    let accountId: AccountId
    let chainAsset: ChainAsset
    let pageSize: Int
    let operationQueue: OperationQueue
    let completionClosure: TransactionSyncResultClosure

    @Atomic(defaultValue: nil) private var cancellable: CancellableCall?

    init(
        chainAsset: ChainAsset,
        accountId: AccountId,
        remoteOperationFactory: WalletRemoteHistoryFactoryProtocol,
        repository: AnyDataProviderRepository<TransactionHistoryItem>,
        pageSize: Int,
        operationQueue: OperationQueue,
        completionClosure: @escaping TransactionSyncResultClosure
    ) {
        self.remoteOperationFactory = remoteOperationFactory
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.repository = repository
        self.pageSize = pageSize
        self.operationQueue = operationQueue
        self.completionClosure = completionClosure
    }

    private func createLocalSaveWrapper(
        depending mergeOperation: BaseOperation<TransactionHistoryMergeResult>
    ) -> BaseOperation<Void> {
        repository.saveOperation({
            try mergeOperation.extractNoCancellableResultData().historyItems
        }, {
            let result = try mergeOperation.extractNoCancellableResultData()

            /**
             *  We delete local items that appeared remotely but as we also save remote items then
             *  no need to remove them locally.
             */
            let savedItemsDict = result.historyItems.reduceToDict()
            return result.identifiersToRemove.filter { savedItemsDict[$0] == nil }
        })
    }

    private func createHistoryMergeOperation(
        dependingOn remoteOperation: BaseOperation<WalletRemoteHistoryData>,
        localOperation: BaseOperation<[TransactionHistoryItem]>,
        chainAsset: ChainAsset
    ) -> BaseOperation<TransactionHistoryMergeResult> {
        ClosureOperation {
            let remoteTransactions = try remoteOperation.extractNoCancellableResultData().historyItems
            let localTransactions = try localOperation.extractNoCancellableResultData()

            if !localTransactions.isEmpty {
                let manager = TransactionHistoryMergeManager(chainAsset: chainAsset)

                return manager.merge(remoteItems: remoteTransactions, localItems: localTransactions)
            } else {
                let transactions: [TransactionHistoryItem] = remoteTransactions.compactMap { item in
                    item.createTransaction(chainAsset: chainAsset)
                }

                return TransactionHistoryMergeResult(historyItems: transactions, identifiersToRemove: [])
            }
        }
    }

    private func createRemoteOperationWrapper() -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        let pagination = Pagination(count: pageSize, context: nil)

        return remoteOperationFactory.createOperationWrapper(
            for: accountId,
            pagination: pagination
        )
    }

    override func performSyncUp() {
        let remoteFetchWrapper = createRemoteOperationWrapper()
        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        localFetchOperation.addDependency(remoteFetchWrapper.targetOperation)

        let mergeOperation = createHistoryMergeOperation(
            dependingOn: remoteFetchWrapper.targetOperation,
            localOperation: localFetchOperation,
            chainAsset: chainAsset
        )

        mergeOperation.addDependency(localFetchOperation)

        let saveOperation = createLocalSaveWrapper(depending: mergeOperation)

        saveOperation.addDependency(mergeOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: remoteFetchWrapper.allOperations + [localFetchOperation, mergeOperation]
        )

        saveOperation.completionBlock = { [weak self] in
            guard self?.cancellable === wrapper else {
                return
            }

            self?.cancellable = nil

            do {
                // check that flow completed successfully
                try saveOperation.extractNoCancellableResultData()

                let remoteData = try remoteFetchWrapper.targetOperation.extractNoCancellableResultData()

                self?.complete(nil)
                self?.completionClosure(remoteData)

            } catch {
                self?.complete(error)
            }
        }

        cancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    override func stopSyncUp() {
        clear(cancellable: &cancellable)
    }
}
