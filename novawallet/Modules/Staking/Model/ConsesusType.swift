import Foundation

enum ConsensusType {
    case babe
    case auraGeneral
    case auraAzero

    init?(stakingType: StakingType) {
        switch stakingType {
        case .relaychain, .nominationPools:
            self = .babe
        case .auraRelaychain:
            self = .auraGeneral
        case .azero:
            self = .auraAzero
        case .parachain, .turing, .unsupported:
            return nil
        }
    }
}
