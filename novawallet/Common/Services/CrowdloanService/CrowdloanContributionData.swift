import BigInt
import RobinHood

struct CrowdloanContributionData {
    let accountId: AccountId
    let chainId: ChainModel.Id
    let paraId: ParaId
    let source: String?
    let amount: BigUInt

    enum SourceType: String {
        case onChain
        case offChain
    }
}

extension CrowdloanContributionData: Identifiable {
    var identifier: String {
        Self.createIdentifier(for: chainId, accountId: accountId, paraId: paraId, source: source)
    }

    static func createIdentifier(
        for chainId: ChainModel.Id,
        accountId: AccountId,
        paraId: ParaId,
        source: String?
    ) -> String {
        let data = [
            chainId,
            accountId.toHex(),
            paraId.toHex(),
            source
        ].compactMap { $0 }
            .joined(separator: "-")
            .data(using: .utf8)!
        return data.sha256().toHex()
    }
}
