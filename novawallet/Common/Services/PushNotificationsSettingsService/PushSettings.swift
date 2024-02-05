import FirebaseCore
import FirebaseFirestore
import SubstrateSdk

typealias ChainSelection = PushSettings.Selection<[String]>

struct PushSettings: Codable, Equatable {
    struct Wallet: Codable, Equatable {
        let baseSubstrate: AccountAddress
        let baseEthereum: AccountAddress?
        let chainSpecific: [String: String]
    }

    struct Notifications: Codable, Equatable {
        let announcements: Bool
        let stakingReward: ChainSelection
        let transfer: ChainSelection
    }

    let pushToken: String
    let updatedAt: Date
    let wallets: [Wallet]
    let notifications: Notifications
}

extension PushSettings {
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

extension PushSettings {
    static func createDefault(for token: String) -> PushSettings {
        .init(
            pushToken: token,
            updatedAt: Date(),
            wallets: [],
            notifications: .init(announcements: true, stakingReward: .all, transfer: .all)
        )
    }
}
