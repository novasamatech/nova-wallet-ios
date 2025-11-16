import BigInt
import Operation_iOS

struct CrowdloanContributionData: Equatable {
    let accountId: AccountId
    let chainAssetId: ChainAssetId
    let paraId: ParaId
    let source: String?
    let amount: BigUInt

    var chainId: ChainModel.Id {
        chainAssetId.chainId
    }

    var type: SourceType {
        if let source = source, !source.isEmpty {
            return .offChain
        } else {
            return .onChain
        }
    }

    enum SourceType: String {
        case onChain
        case offChain
    }

    func addingNewAmount(_ newAmount: Balance) -> CrowdloanContributionData {
        CrowdloanContributionData(
            accountId: accountId,
            chainAssetId: chainAssetId,
            paraId: paraId,
            source: source,
            amount: amount + newAmount
        )
    }
}

extension CrowdloanContributionData: Identifiable {
    var identifier: String {
        Self.createIdentifier(for: chainAssetId, accountId: accountId, paraId: paraId, source: source)
    }

    static func createIdentifier(
        for chainAssetId: ChainAssetId,
        accountId: AccountId,
        paraId: ParaId,
        source: String?
    ) -> String {
        let data = [
            chainAssetId.stringValue,
            accountId.toHex(),
            paraId.toHex(),
            source
        ].compactMap { $0 }
            .joined(separator: "-")
            .data(using: .utf8)!
        return data.sha256().toHex()
    }
}
