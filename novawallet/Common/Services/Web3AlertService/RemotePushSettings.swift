import FirebaseCore
import FirebaseFirestore
import SubstrateSdk
import RobinHood

typealias ChainSelection = RemotePushSettings.Selection<[String]>

struct Web3AlertWallet: Codable, Equatable {
    let baseSubstrate: AccountAddress?
    let baseEthereum: AccountAddress?
    let chainSpecific: [String: String]
}

struct Web3AlertNotification: Codable, Equatable {
    let stakingReward: ChainSelection
    let transfer: ChainSelection
}

struct RemotePushSettings: Codable, Equatable {
    let pushToken: String
    let updatedAt: Date
    let wallets: [Web3AlertWallet]
    let notifications: Web3AlertNotification

    init(from local: LocalPushSettings) {
        pushToken = local.pushToken
        updatedAt = local.updatedAt
        wallets = local.wallets
        notifications = local.notifications
    }
}

extension RemotePushSettings {
    enum Selection<T: Codable & Equatable>: Codable, Equatable {
        case all
        case concrete(T)

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
}
