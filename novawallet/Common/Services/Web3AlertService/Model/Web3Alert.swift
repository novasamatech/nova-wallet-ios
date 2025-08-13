import Foundation

enum Web3Alert {
    typealias LocalChainId = ChainModel.Id
    typealias RemoteChainId = String

    struct Wallet<C: Codable & Hashable>: Codable, Equatable {
        let baseSubstrate: AccountAddress?
        let baseEthereum: AccountAddress?
        let chainSpecific: [C: AccountAddress]
    }

    enum Selection<T> {
        case all
        case concrete(T)

        var concreteValue: T? {
            switch self {
            case .all:
                return nil
            case let .concrete(value):
                return value
            }
        }

        func mapConcreteValue<N>(closure: (T) -> N) -> Selection<N> {
            switch self {
            case .all:
                return .all
            case let .concrete(value):
                return .concrete(closure(value))
            }
        }
    }

    struct Notifications<C: Codable & Equatable>: Codable, Equatable {
        var stakingReward: Selection<C>?
        var tokenSent: Selection<C>?
        var tokenReceived: Selection<C>?
        var newMultisig: Selection<C>?
        var multisigApproval: Selection<C>?
        var multisigExecuted: Selection<C>?
        var multisigCanceled: Selection<C>?
    }
}

extension Web3Alert.Selection: Codable, Equatable where T: Codable & Equatable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum Keys: String {
        case all
        case concrete
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch Keys(rawValue: type) {
        case .all:
            self = .all
        case .concrete:
            let value = try container.decode(T.self, forKey: .value)
            self = .concrete(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "unexpected value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all:
            try container.encode(Keys.all.rawValue, forKey: .type)
        case let .concrete(value):
            try container.encode(Keys.concrete.rawValue, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}
