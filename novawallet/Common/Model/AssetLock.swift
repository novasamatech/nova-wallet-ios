import BigInt
import Operation_iOS

enum AssetLockStorage: String {
    case locks = "Locks"
    case freezes = "Freezes"
}

/**
 * The model is used for legacy Locks and new Freezes data,
 * as they have the same logic: amount can be reused by different entities.
 */
struct AssetLock: Equatable {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let type: Data
    let amount: BigUInt

    // whether the model represents locks or freezes
    let storage: String

    let module: String?

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
        storage: String,
        accountId: AccountId,
        module: String?,
        type: Data
    ) -> String {
        let data = [
            chainAssetId.stringValue,
            storage,
            accountId.toHex(),
            module,
            type.toUTF8String()!
        ].compactMap { $0 }.joined(with: String.Separator.dash).data(using: .utf8)!
        return data.sha256().toHex()
    }

    var identifier: String {
        Self.createIdentifier(for: chainAssetId, storage: storage, accountId: accountId, module: module, type: type)
    }
}

extension AssetLock: CustomDebugStringConvertible {
    var debugDescription: String {
        [
            "ChainAsset: \(chainAssetId.stringValue)",
            "AccountId: \(accountId.toHex())",
            "Type: \(type.toUTF8String() ?? "")",
            "Module: \(module ?? "")",
            "Amount: \(amount)"
        ].joined(separator: "\n")
    }
}

extension AssetLock: Codable {}
