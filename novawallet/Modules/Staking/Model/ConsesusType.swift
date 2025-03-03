import Foundation

enum ConsensusType {
    case babe
    case auraGeneral
    case auraAzero

    init?(stakingType: StakingType) {
        switch stakingType {
        case .relaychain:
            self = .babe
        case .auraRelaychain:
            self = .auraGeneral
        case .azero:
            self = .auraAzero
        case .parachain, .turing, .mythos, .unsupported, .nominationPools:
            return nil
        }
    }

    init?(asset: AssetModel) {
        let optMainStakingType = asset.stakings?.sorted { type1, type2 in
            type1.isMorePreferred(than: type2)
        }.first

        guard let mainStakingType = optMainStakingType else {
            return nil
        }

        self.init(stakingType: mainStakingType)
    }

    var stakingType: StakingType {
        switch self {
        case .babe:
            return .relaychain
        case .auraGeneral:
            return .auraRelaychain
        case .auraAzero:
            return .azero
        }
    }
}
