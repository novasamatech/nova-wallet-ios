import Foundation

enum StakingType: String, Equatable {
    case relaychain
    case parachain
    case unsupported

    init(rawType: String?) {
        if let rawType = rawType, let value = StakingType(rawValue: rawType) {
            self = value
        } else {
            self = .unsupported
        }
    }
}
