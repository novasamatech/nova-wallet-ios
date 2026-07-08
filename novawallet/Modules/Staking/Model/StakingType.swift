import Foundation

enum StakingType: String, Codable, Equatable, Hashable {
    case relaychain
    case parachain
    case azero = "aleph-zero"
    case auraRelaychain = "aura-relaychain"
    case turing
    case nominationPools = "nomination-pools"
    case mythos
    case unsupported

    init(rawType: String?) {
        if let rawType = rawType, let value = StakingType(rawValue: rawType) {
            self = value
        } else {
            self = .unsupported
        }
    }

    func isMorePreferred(than stakingType: StakingType) -> Bool {
        StakingClass(stakingType: self).preferringRating < StakingClass(stakingType: stakingType).preferringRating
    }

    /// Analytics-friendly name matching Android StakingType enum (lowercase, underscores).
    var analyticsName: String {
        switch self {
        case .relaychain:
            return "relaychain"
        case .parachain:
            return "parachain"
        case .azero:
            return "aleph_zero"
        case .auraRelaychain:
            return "relaychain_aura"
        case .turing:
            return "turing"
        case .nominationPools:
            return "nomination_pools"
        case .mythos:
            return "mythos"
        case .unsupported:
            return "unsupported"
        }
    }
}

enum StakingClass {
    case relaychain
    case parachain
    case nominationPools
    case unsupported

    // lesser better
    var preferringRating: UInt8 {
        switch self {
        case .relaychain:
            return 0
        case .parachain:
            return 1
        case .nominationPools:
            return 2
        case .unsupported:
            return 3
        }
    }

    init(stakingType: StakingType) {
        switch stakingType {
        case .relaychain, .azero, .auraRelaychain:
            self = .relaychain
        case .parachain, .turing, .mythos:
            self = .parachain
        case .nominationPools:
            self = .nominationPools
        case .unsupported:
            self = .unsupported
        }
    }
}
