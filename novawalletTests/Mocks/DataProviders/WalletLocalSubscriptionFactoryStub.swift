import Foundation
@testable import novawallet
import Operation_iOS
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
                frozenInPlank: 0,
                edCountMode: .basedOnFree,
                transferrableMode: .fungibleTrait,
                blocked: false
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

    func getAccountBalanceProvider(for _: AccountId) throws -> StreamableProvider<AssetBalance> {
        throw CommonError.undefined
    }

    func getAllBalancesProvider() throws -> StreamableProvider<AssetBalance> {
        throw CommonError.undefined
    }

    func getLocksProvider(for _: AccountId) throws -> StreamableProvider<AssetLock> {
        throw CommonError.undefined
    }

    func getLocksProvider(
        for _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) throws -> StreamableProvider<AssetLock> {
        throw CommonError.undefined
    }

    func getHoldsProvider(for _: AccountId) throws -> StreamableProvider<AssetHold> {
        throw CommonError.undefined
    }

    func getHoldsProvider(
        for _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) throws -> StreamableProvider<AssetHold> {
        throw CommonError.undefined
    }
}
