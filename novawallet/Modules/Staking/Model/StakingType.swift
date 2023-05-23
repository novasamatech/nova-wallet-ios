import Foundation

enum StakingType: String, Codable, Equatable {
    case relaychain
    case parachain
    case azero = "aleph-zero"
    case auraRelaychain = "aura-relaychain"
    case turing
    case unsupported

    init(rawType: String?) {
        if let rawType = rawType, let value = StakingType(rawValue: rawType) {
            self = value
        } else {
            self = .unsupported
        }
    }
}
