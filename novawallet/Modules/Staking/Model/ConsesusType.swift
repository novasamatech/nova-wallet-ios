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
        case .parachain, .turing, .unsupported, .nominationPools:
            return nil
        }
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
