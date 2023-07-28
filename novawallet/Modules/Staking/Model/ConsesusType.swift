import Foundation

enum ConsensusType {
    case babe
    case aura

    init?(stakingType: StakingType) {
        switch stakingType {
        case .relaychain, .nominationPools:
            self = .babe
        case .auraRelaychain, .azero:
            self = .aura
        case .parachain, .turing, .unsupported:
            return nil
        }
    }
}
