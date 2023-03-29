import Foundation
import RobinHood
import CommonWallet

final class TransactionHistoryRemoteFetcher: AnyCancellableCleaning {
    let operationFactory: WalletRemoteHistoryFactoryProtocol
    let operationQueue: OperationQueue
    let address: AccountAddress
    let chainAsset: ChainAsset
    let pageSize: Int

    @Atomic private var pagination: Pagination?
    @Atomic private var pendingOperation: CancellableCall?

    weak var delegate: TransactionHistoryFetcherDelegate?

    init(
        address: AccountAddress,
        chainAsset: ChainAsset,
        operationFactory: WalletRemoteHistoryFactoryProtocol,
        operationQueue: OperationQueue,
        pageSize: Int,
        initPagination: Pagination? = nil
    ) {
        self.address = address
        self.chainAsset = chainAsset
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
        self.pageSize = pageSize
        self.pagination = initPagination
    }

    deinit {
        clear(cancellable: &pendingOperation)
    }

    private func performFetch() {
        guard pendingOperation == nil else {
            return
        }

        let currentPagination = pagination ?? Pagination(count: pageSize, context: nil)

        let wrapper = operationFactory.createOperationWrapper(for: address, pagination: currentPagination)

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.pendingOperation = nil

                guard let strongSelf = self else {
                    return
                }

                do {
                    let result = try wrapper.targetOperation.extractNoCancellableResultData()

                    let changes = result.historyItems
                        .compactMap { $0.createTransaction(chainAsset: strongSelf.chainAsset) }
                        .map { DataProviderChange.insert(newItem: $0) }

                    strongSelf.pagination = .init(count: strongSelf.pageSize, context: result.context)

                    strongSelf.delegate?.didReceiveHistoryChanges(strongSelf, changes: changes)
                } catch {
                    strongSelf.delegate?.didReceiveHistoryError(strongSelf, error: .remoteFetchFailed(error))
                }
            }
        }

        pendingOperation = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
    }
}

extension TransactionHistoryRemoteFetcher: TransactionHistoryFetching {
    var isComplete: Bool {
        if let pagination = pagination {
            return operationFactory.isComplete(pagination: pagination)
        } else {
            return false
        }
    }

    var isFetching: Bool {
        pendingOperation != nil
    }

    func start() {
        performFetch()
    }

    func fetchNext() {
        performFetch()
    }
}
