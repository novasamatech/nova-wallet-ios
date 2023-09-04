import Foundation
import BigInt
import SubstrateSdk
import RobinHood

struct PooledAssetBalance: Equatable {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let amount: BigUInt
    let poolId: NominationPools.PoolId
}

extension PooledAssetBalance: Identifiable {
    var identifier: String {
        Self.createIdentifier(from: chainAssetId, accountId: accountId)
    }

    static func createIdentifier(from chainAssetId: ChainAssetId, accountId: AccountId) -> String {
        ExternalAssetBalance.BalanceType.nominationPools.rawValue + "-" +
            chainAssetId.stringValue + "-" + accountId.toHex()
    }
}
