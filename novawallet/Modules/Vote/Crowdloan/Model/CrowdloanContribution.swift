import BigInt
import Operation_iOS

struct CrowdloanContribution: Equatable {
    let accountId: AccountId
    let chainAssetId: ChainAssetId
    let paraId: ParaId
    let unlocksAt: BlockNumber
    let amount: BigUInt
    let depositor: AccountId?

    var chainId: ChainModel.Id {
        chainAssetId.chainId
    }
}

extension CrowdloanContribution: Identifiable {
    var identifier: String {
        Self.createIdentifier(for: chainAssetId, accountId: accountId, paraId: paraId, unlocksAt: unlocksAt)
    }

    static func createIdentifier(
        for chainAssetId: ChainAssetId,
        accountId: AccountId,
        paraId: ParaId,
        unlocksAt: BlockNumber
    ) -> String {
        let data = [
            chainAssetId.stringValue,
            accountId.toHex(),
            paraId.toHex(),
            unlocksAt.toHex()
        ].joined(with: .dash).data(using: .utf8)!
        return data.sha256().toHex()
    }
}

extension Array where Element == CrowdloanContribution {
    func totalAmountLocked() -> Balance {
        reduce(Balance(0)) { $0 + $1.amount }
    }

    func sortedByUnlockTime() -> [CrowdloanContribution] {
        sorted { $0.unlocksAt < $1.unlocksAt }
    }
}
