import Foundation
import BigInt
import Operation_iOS

struct SubtensorStakedBalance: Equatable {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let amount: BigUInt
}

extension SubtensorStakedBalance: Identifiable {
    var identifier: String {
        Self.createIdentifier(from: chainAssetId, accountId: accountId)
    }

    static func createIdentifier(from chainAssetId: ChainAssetId, accountId: AccountId) -> String {
        ExternalAssetBalance.BalanceType.subtensorStaking.rawValue + "-" +
            chainAssetId.stringValue + "-" + accountId.toHex()
    }
}
