import Foundation
import BigInt
import Operation_iOS

struct AssetHold: Equatable {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let module: String
    let reason: String
    let amount: BigUInt
}

extension AssetHold: Identifiable {
    static func createIdentifier(
        for chainAssetId: ChainAssetId,
        accountId: AccountId,
        module: String,
        reason: String
    ) -> String {
        let data = [
            chainAssetId.stringValue,
            accountId.toHex(),
            module,
            reason
        ].joined(separator: "-").data(using: .utf8)!
        return data.sha256().toHex()
    }

    var identifier: String {
        Self.createIdentifier(
            for: chainAssetId,
            accountId: accountId,
            module: module,
            reason: reason
        )
    }
}
