import FirebaseCore
import FirebaseFirestore
import SubstrateSdk
import RobinHood

extension Web3Alert {
    typealias ChainId = String

    struct Wallet: Codable, Equatable {
        let baseSubstrate: AccountAddress?
        let baseEthereum: AccountAddress?
        let chainSpecific: [ChainId: AccountAddress]
    }

    struct Notifications: Codable, Equatable {
        var stakingReward: ChainSelection?
        var transfer: ChainSelection?
        var tokenSent: ChainSelection?
        var tokenReceived: ChainSelection?
    }

    struct RemoteSettings: Codable, Equatable {
        let pushToken: String
        let updatedAt: Date
        let wallets: [Wallet]
        let notifications: Notifications

        init(from local: Web3Alert.LocalSettings) {
            pushToken = local.pushToken
            updatedAt = local.updatedAt
            wallets = local.wallets.map(\.remoteModel)
            notifications = local.notifications
        }
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
    }

    typealias ChainSelection = Selection<[ChainId]>
}

extension Web3Alert.ChainSelection {
    var notificationsEnabled: Bool {
        switch self {
        case .all:
            return true
        case let .concrete(chains):
            return !chains.isEmpty
        }
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

extension Optional where Wrapped == Web3Alert.ChainSelection {
    mutating func toggle() {
        switch self {
        case .none:
            self = .all
        case .all:
            self = nil
        case .concrete:
            self = nil
        }
    }
}
