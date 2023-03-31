import Foundation
import RobinHood
import web3swift
import Core
import SubstrateSdk
import BigInt

typealias EvmNativeUpdateServiceCompletionClosure = (Bool) -> Void

final class EvmNativeBalanceUpdateService: BaseSyncService, AnyCancellableCleaning {
    let chainAssetId: ChainAssetId
    let holder: AccountAddress
    let connection: JSONRPCEngine
    let repository: AnyDataProviderRepository<AssetBalance>
    let operationQueue: OperationQueue
    let blockNumber: Core.BlockNumber
    let completion: EvmNativeUpdateServiceCompletionClosure?

    @Atomic(defaultValue: nil) private var queryId: UInt16?
    @Atomic(defaultValue: nil) private var cancellable: CancellableCall?

    init(
        holder: AccountAddress,
        chainAssetId: ChainAssetId,
        connection: JSONRPCEngine,
        repository: AnyDataProviderRepository<AssetBalance>,
        operationQueue: OperationQueue,
        blockNumber: Core.BlockNumber,
        logger: LoggerProtocol?,
        completion: EvmNativeUpdateServiceCompletionClosure?
    ) {
        self.holder = holder
        self.chainAssetId = chainAssetId
        self.connection = connection
        self.repository = repository
        self.operationQueue = operationQueue
        self.blockNumber = blockNumber
        self.completion = completion

        super.init(logger: logger)
    }

    private func createSaveOperation(
        dependingOn localBalancesOperation: BaseOperation<AssetBalance?>,
        chainAssetId: ChainAssetId,
        newBalance: BigUInt,
        holder: AccountAddress
    ) -> BaseOperation<Void> {
        repository.saveOperation({
            let oldBalance = try localBalancesOperation.extractNoCancellableResultData()?.totalInPlank

            let accountId = try holder.toEthereumAccountId()

            guard newBalance > 0, newBalance != oldBalance else {
                return []
            }

            let assetBalance = AssetBalance(
                chainAssetId: chainAssetId,
                accountId: accountId,
                freeInPlank: newBalance,
                reservedInPlank: 0,
                frozenInPlank: 0
            )

            return [assetBalance]
        }, {
            // remove zero balances

            let optBalanceId = try localBalancesOperation.extractNoCancellableResultData()?.identifier

            guard newBalance == 0, let balanceId = optBalanceId else {
                return []
            }

            return [balanceId]
        })
    }

    private func saveAndComplete(balance: BigUInt, holder: AccountAddress) {
        let localBalanceFetchOperation = repository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )

        let localBalanceMapOperation = ClosureOperation<AssetBalance?> {
            try localBalanceFetchOperation.extractNoCancellableResultData().first
        }

        localBalanceMapOperation.addDependency(localBalanceFetchOperation)

        let saveOperation = createSaveOperation(
            dependingOn: localBalanceMapOperation,
            chainAssetId: chainAssetId,
            newBalance: balance,
            holder: holder
        )

        saveOperation.addDependency(localBalanceMapOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: [localBalanceFetchOperation, localBalanceMapOperation]
        )

        saveOperation.completionBlock = { [weak self] in
            guard self?.cancellable === wrapper else {
                return
            }

            self?.cancellable = nil

            do {
                try saveOperation.extractNoCancellableResultData()
                self?.complete(nil)

                let oldBalance = try localBalanceMapOperation.extractNoCancellableResultData()?.totalInPlank ?? 0

                let hasChanges = balance != oldBalance
                self?.completion?(hasChanges)
            } catch {
                self?.complete(error)
            }
        }

        cancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
    }

    private func extractBalance(from result: Result<String, Error>) -> BigUInt? {
        switch result {
        case let .success(balance):
            let balanceValue = BigUInt.fromHexString(balance)

            if balanceValue == nil {
                logger?.warning("Unexpected nil balance: \(chainAssetId)")
            }

            return balanceValue
        case let .failure(error):
            logger?.error("Unexpected error: \(error)")
            return nil
        }
    }

    private func fetchBalance(for holder: AccountAddress) {
        do {
            let params = EvmBalanceMessage.Params(holder: holder, block: blockNumber)
            queryId = try connection.callMethod(
                EvmBalanceMessage.method,
                params: params,
                options: .init(resendOnReconnect: true)
            ) { [weak self] (result: Result<String, Error>) in
                guard let balance = self?.extractBalance(from: result) else {
                    return
                }

                self?.saveAndComplete(balance: balance, holder: holder)
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

        clear(cancellable: &cancellable)
    }
}
