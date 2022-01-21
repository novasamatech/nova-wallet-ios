import Foundation
import BigInt
import RobinHood

struct AssetBalance: Equatable {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let freeInPlank: BigUInt
    let reservedInPlank: BigUInt
    let frozenInPlank: BigUInt

    var totalInPlank: BigUInt { freeInPlank + reservedInPlank }
}

extension AssetBalance: Identifiable {
    static func createIdentifier(for chainAssetId: ChainAssetId, accountId: AccountId) -> String {
        chainAssetId.stringValue + "\(accountId.toHex())"
    }

    var identifier: String { Self.createIdentifier(for: chainAssetId, accountId: accountId) }
}
