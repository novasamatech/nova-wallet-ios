import Foundation
@testable import novawallet
import RobinHood
import BigInt

final class WalletLocalSubscriptionFactoryStub: WalletLocalSubscriptionFactoryProtocol {
    let balance: BigUInt?

    let operationQueue: OperationQueue

    init(balance: BigUInt? = nil, operationQueue: OperationQueue = OperationQueue()) {
        self.balance = balance
        self.operationQueue = operationQueue
    }

    func getDummyBalance(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) -> AssetBalance? {
        if let balance = balance {
            return AssetBalance(
                chainAssetId: ChainAssetId(chainId: chainId, assetId: assetId),
                accountId: accountId,
                freeInPlank: balance,
                reservedInPlank: 0,
                frozenInPlank: 0
            )
        } else {
            return nil
        }
    }

    func getAssetBalanceProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) throws -> StreamableProvider<AssetBalance> {
        let models: [AssetBalance]

        if
            let balance = getDummyBalance(
                for: accountId,
                chainId: chainId,
                assetId: assetId
            ) {
            models = [balance]
        } else {
            models = []
        }

        let repository = DataProviderRepositoryStub(models: models)
        let repositoryObservable = DataProviderObservableStub<AssetBalance>()

        return StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource()),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(repositoryObservable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }

    func getAccountBalanceProvider(for accountId: AccountId) throws -> StreamableProvider<AssetBalance> {
        throw CommonError.undefined
    }

    func getAllBalancesProvider() throws -> StreamableProvider<AssetBalance> {
        throw CommonError.undefined
    }
    
    func getLocksProvider(for accountId: AccountId) throws -> StreamableProvider<AssetLock> {
        throw CommonError.undefined
    }

    func getLocksProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) throws -> StreamableProvider<AssetLock> {
        throw CommonError.undefined
    }
}
