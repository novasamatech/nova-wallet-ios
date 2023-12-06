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

    enum ProxyType: String, Hashable, Decodable {
        case any
        case nonTransfer
        case governance
        case staking
        case other

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
                self = .other
            }
        }
    }
}
