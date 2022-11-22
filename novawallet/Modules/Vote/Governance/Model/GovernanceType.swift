import Foundation

enum GovernanceType: String, Equatable {
    case governanceV1 = "governance-v1"
    case governanceV2 = "governance"

    func title(for chain: ChainModel) -> String {
        guard let asset = chain.utilityAsset() else {
            return ""
        }

        let assetTitle = asset.name ?? chain.name

        switch self {
        case .governanceV1:
            return assetTitle + " " + "Governance v1"
        case .governanceV2:
            return assetTitle + " " + "OpenGov"
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
