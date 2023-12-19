import Foundation
import SubstrateSdk
import BigInt

enum Proxy {
    static var moduleName: String {
        "proxy"
    }

    struct ProxyDefinition: Decodable {
        let delegate: AccountId
        let proxyType: ProxyType
        @StringCodable var delay: BlockNumber
    }

    enum ProxyType: Hashable, Decodable {
        case any
        case nonTransfer
        case governance
        case staking
        case other(String)

        enum Field {
            static let any = "Any"
            static let nonTransfer = "NonTransfer"
            static let governance = "Governance"
            static let staking = "Staking"
        }

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case Field.any:
                self = .any
            case Field.nonTransfer:
                self = .nonTransfer
            case Field.governance:
                self = .governance
            case Field.staking:
                self = .staking
            default:
                self = .other(type)
            }
        }

        init(id: String) {
            switch id {
            case "any":
                self = .any
            case "nonTransfer":
                self = .nonTransfer
            case "governance":
                self = .governance
            case "staking":
                self = .staking
            default:
                self = .other(id)
            }
        }

        var id: String {
            switch self {
            case .any:
                return "any"
            case .nonTransfer:
                return "nonTransfer"
            case .governance:
                return "governance"
            case .staking:
                return "staking"
            case let .other(value):
                return value
            }
        }
    }
}
