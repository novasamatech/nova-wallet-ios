import Foundation
@testable import novawallet
import RobinHood
import BigInt

final class WalletLocalSubscriptionFactoryStub: WalletLocalSubscriptionFactoryProtocol {
    let balance: BigUInt?

    init(balance: BigUInt? = nil) {
        self.balance = balance
    }

    func getAccountProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedAccountInfo> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let accountInfo = balance.map { value in
            AccountInfo(
                nonce: 0,
                data: AccountData(
                    free: value,
                    reserved: 0,
                    miscFrozen: 0,
                    feeFrozen: 0
                )
            )
        }

        let accountInfoModel: DecodedAccountInfo = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(
                .account,
                accountId: accountId,
                chainId: chainId
            )

            if let accountInfo = accountInfo {
                return DecodedAccountInfo(identifier: localKey, item: accountInfo)
            } else {
                return DecodedAccountInfo(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [accountInfoModel]))
    }

    func getAssetBalanceProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) throws -> StreamableProvider<AssetBalance> {
        throw CommonError.undefined
    }

    func getAccountBalanceProvider(for accountId: AccountId) throws -> StreamableProvider<AssetBalance> {
        throw CommonError.undefined
    }
}
