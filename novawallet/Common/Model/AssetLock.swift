import BigInt
import Operation_iOS

struct AssetLock: Equatable {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let type: Data
    let amount: BigUInt

    var lockType: LockType? {
        guard let typeString = displayId else {
            return nil
        }
        return LockType(rawValue: typeString.lowercased())
    }

    var displayId: String? {
        String(data: type, encoding: .utf8)?.trimmingCharacters(in: .whitespaces)
    }
}

extension AssetLock: Identifiable {
    static func createIdentifier(
        for chainAssetId: ChainAssetId,
        accountId: AccountId,
        type: Data
    ) -> String {
        let data = [
            chainAssetId.stringValue,
            accountId.toHex(),
            type.toUTF8String()!
        ].joined(separator: "-").data(using: .utf8)!
        return data.sha256().toHex()
    }

    var identifier: String {
        Self.createIdentifier(for: chainAssetId, accountId: accountId, type: type)
    }
}

extension AssetLock: CustomDebugStringConvertible {
    var debugDescription: String {
        [
            "ChainAsset: \(chainAssetId.stringValue)",
            "AccountId: \(accountId.toHex())",
            "Type: \(type.toUTF8String() ?? "")",
            "Amount: \(amount)"
        ].joined(separator: "\n")
    }
}

extension AssetLock: Codable {}
