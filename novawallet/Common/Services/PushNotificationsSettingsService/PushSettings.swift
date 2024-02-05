import FirebaseCore
import FirebaseFirestore

typealias ChainSelection = PushSettings.Selection<String>

struct PushSettings: Codable, Equatable {
    struct Wallet: Codable, Equatable {
        let baseSubstrate: AccountAddress
        let baseEthereum: AccountAddress?
        let chainSpecific: [String: String]
    }

    enum Selection<T: Codable & Equatable>: Codable, Equatable {
        case all
        case concrete(T)

        init(from decoder: Decoder) throws {
            var container = try decoder.singleValueContainer()
            let type = try container.decode(String.self)

            switch type {
            case "all":
                self = .all
            case "concrete":
                let value = try container.decode(T.self)
                self = .concrete(value)
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "unexpected value"
                )
            }
        }

        func encode(to _: Encoder) throws {
            fatalError()
        }
    }

    enum Notification: Codable, Equatable {
        case stakingReward(ChainSelection)
        case transfer(ChainSelection)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let type = try container.decode(String.self)

            switch type {
            case "stakingReward":
                let chains = try container.decode(ChainSelection.self)
                self = .stakingReward(chains)
            case "transfer":
                let chains = try container.decode(ChainSelection.self)
                self = .transfer(chains)
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "unexpected value"
                )
            }
        }

        func encode(to _: Encoder) throws {
            fatalError()
        }
    }

    let pushToken: String
    let updatedAt: String
    let wallets: [Wallet]
    let notifications: [Notification]
}
