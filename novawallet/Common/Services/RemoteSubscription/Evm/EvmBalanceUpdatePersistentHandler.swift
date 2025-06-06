import Foundation
import Operation_iOS
import Core

final class EvmBalanceUpdatePersistentHandler {
    let repository: AnyDataProviderRepository<AssetBalance>
    let operationQueue: OperationQueue

    init(repository: AnyDataProviderRepository<AssetBalance>, operationQueue: OperationQueue) {
        self.repository = repository
        self.operationQueue = operationQueue
    }
}

private extension EvmBalanceUpdatePersistentHandler {
    func createSaveOperation(
        dependingOn localBalancesOperation: BaseOperation<[ChainAssetId: AssetBalance]>,
        balances: [ChainAssetId: Balance],
        holder: AccountAddress
    ) -> BaseOperation<Void> {
        repository.saveOperation({
            let localBalancesDict = try localBalancesOperation.extractNoCancellableResultData()

            let accountId = try holder.toEthereumAccountId()

            return balances.compactMap { keyValue in
                // add new balance or update existing

                let chainAssetId = keyValue.key
                let newBalance = keyValue.value
                let oldBalance = localBalancesDict[chainAssetId]?.totalInPlank

                guard newBalance > 0, newBalance != oldBalance else {
                    return nil
                }

                return AssetBalance(
                    evmBalance: newBalance,
                    accountId: accountId,
                    chainAssetId: chainAssetId
                )
            }
        }, {
            // remove zero balances

            let localBalancesDict = try localBalancesOperation.extractNoCancellableResultData()

            return balances.compactMap { keyValue in
                let chainAssetId = keyValue.key
                let newBalance = keyValue.value

                guard newBalance == 0, let oldBalance = localBalancesDict[chainAssetId] else {
                    return nil
                }

                return oldBalance.identifier
            }
        })
    }

    func createSaveWrapper(
        balances: [ChainAssetId: Balance],
        holder: AccountAddress
    ) -> CompoundOperationWrapper<Bool> {
        let localBalancesFetchOperation = repository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )

        let localBalancesMapOperation = ClosureOperation<[ChainAssetId: AssetBalance]> {
            let localAssetBalances = try localBalancesFetchOperation.extractNoCancellableResultData()
            return localAssetBalances.reduce(into: [ChainAssetId: AssetBalance]()) {
                $0[$1.chainAssetId] = $1
            }
        }

        localBalancesMapOperation.addDependency(localBalancesFetchOperation)

        let saveOperation = createSaveOperation(
            dependingOn: localBalancesMapOperation,
            balances: balances,
            holder: holder
        )

        saveOperation.addDependency(localBalancesMapOperation)

        let hasChangesOperation = ClosureOperation<Bool> {
            try saveOperation.extractNoCancellableResultData()

            let oldAssetBalances = try localBalancesMapOperation.extractNoCancellableResultData()

            let oldBalances = balances.keys.reduce(into: [ChainAssetId: Balance]()) {
                $0[$1] = oldAssetBalances[$1]?.totalInPlank ?? 0
            }

            return balances != oldBalances
        }

        hasChangesOperation.addDependency(saveOperation)
        hasChangesOperation.addDependency(localBalancesMapOperation)

        return CompoundOperationWrapper(
            targetOperation: hasChangesOperation,
            dependencies: [localBalancesFetchOperation, localBalancesMapOperation, saveOperation]
        )
    }
}

extension EvmBalanceUpdatePersistentHandler: EvmBalanceUpdateHandling {
    func onBalanceUpdateWrapper(
        balances: [ChainAssetId: Balance],
        holder: AccountAddress,
        block _: Core.BlockNumber?
    ) -> CompoundOperationWrapper<Bool> {
        createSaveWrapper(balances: balances, holder: holder)
    }
}
