import Foundation
import Operation_iOS
import web3swift
import Core
import SubstrateSdk
import BigInt

typealias EvmNativeUpdateServiceCompletionClosure = (Bool) -> Void

final class EvmNativeBalanceUpdateService: BaseSyncService, AnyCancellableCleaning {
    let chainAssetId: ChainAssetId
    let holder: AccountAddress
    let connection: JSONRPCEngine
    let updateHandler: EvmBalanceUpdateHandling
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue
    let block: EvmBalanceUpdateBlock
    let completion: EvmNativeUpdateServiceCompletionClosure?

    private var queryId: UInt16?
    private let callStore = CancellableCallStore()

    init(
        holder: AccountAddress,
        chainAssetId: ChainAssetId,
        connection: JSONRPCEngine,
        updateHandler: EvmBalanceUpdateHandling,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue,
        block: EvmBalanceUpdateBlock,
        logger: LoggerProtocol,
        completion: EvmNativeUpdateServiceCompletionClosure?
    ) {
        self.holder = holder
        self.chainAssetId = chainAssetId
        self.connection = connection
        self.updateHandler = updateHandler
        self.operationQueue = operationQueue
        self.workQueue = workQueue
        self.block = block
        self.completion = completion

        super.init(logger: logger)
    }

    private func handleAndComplete(balance: Balance, holder: AccountAddress) {
        callStore.cancel()

        let wrapper = updateHandler.onBalanceUpdateWrapper(
            balances: [chainAssetId: balance],
            holder: holder,
            block: block.updateDetectedAt
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(hasChanges):
                self?.completeImmediate(nil)
                self?.completion?(hasChanges)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    private func extractBalance(from result: Result<String, Error>) -> BigUInt? {
        switch result {
        case let .success(balance):
            let balanceValue = BigUInt.fromHexString(balance)

            if balanceValue == nil {
                logger.warning("Unexpected nil balance: \(chainAssetId)")
            }

            return balanceValue
        case let .failure(error):
            logger.error("Unexpected error: \(error)")
            return nil
        }
    }

    private func fetchBalance(for holder: AccountAddress) {
        do {
            let params = EvmBalanceMessage.Params(holder: holder, block: block.fetchRequestedAt)
            queryId = try connection.callMethod(
                EvmBalanceMessage.method,
                params: params,
                options: .init(resendOnReconnect: true)
            ) { [weak self] (result: Result<String, Error>) in
                guard let self else {
                    return
                }

                dispatchInQueueWhenPossible(workQueue, locking: mutex) { [weak self] in
                    guard let self else {
                        return
                    }

                    guard let balance = extractBalance(from: result) else {
                        return
                    }

                    handleAndComplete(balance: balance, holder: holder)
                }
            }
        } catch {
            complete(error)
        }
    }

    override func performSyncUp() {
        fetchBalance(for: holder)
    }

    override func stopSyncUp() {
        if let queryId = queryId {
            connection.cancelForIdentifier(queryId)
        }

        callStore.cancel()
    }
}
