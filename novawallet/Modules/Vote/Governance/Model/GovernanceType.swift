import Foundation

enum GovernanceType: String, Equatable {
    case governanceV1 = "governance-v1"
    case governanceV2 = "governance"

    func title(for chainAsset: ChainAsset) -> String {
        let chain = chainAsset.chain
        let assetName = chainAsset.chainAssetName

        return switch self {
        case .governanceV1 where chain.hasGovernanceV2:
            [assetName, "Governance v1"].joined(with: .space)
        case .governanceV2:
            [assetName, "OpenGov"].joined(with: .space)
        case .governanceV1:
            assetName
        }
    }

    func compatible(with chain: ChainModel) -> Bool {
        switch self {
        case .governanceV1:
            return chain.hasGovernanceV1
        case .governanceV2:
            return chain.hasGovernanceV2
        }
    }
}
