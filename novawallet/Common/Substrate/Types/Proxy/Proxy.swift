import Foundation
import SubstrateSdk
import BigInt

enum Proxy {
    static var name: String { "Proxy" }

    struct ProxyDefinition: Codable, Equatable {
        enum CodingKeys: String, CodingKey {
            case proxy = "delegate"
            case proxyType
            case delay
        }

        @BytesCodable var proxy: AccountId
        let proxyType: ProxyType
        @StringCodable var delay: BlockNumber
    }

    enum ProxyType: Hashable, Codable {
        case any
        case nonTransfer
        case governance
        case staking
        case nominationPools
        case identityJudgement
        case cancelProxy
        case auction
        case other(String)

        enum Field {
            static let any = "Any"
            static let nonTransfer = "NonTransfer"
            static let governance = "Governance"
            static let staking = "Staking"
            static let identityJudgement = "IdentityJudgement"
            static let cancelProxy = "CancelProxy"
            static let auction = "Auction"
            static let nominationPools = "NominationPools"
        }

        public init(rawType: String) {
            switch rawType {
            case Field.any:
                self = .any
            case Field.nonTransfer:
                self = .nonTransfer
            case Field.governance:
                self = .governance
            case Field.staking:
                self = .staking
            case Field.nominationPools:
                self = .nominationPools
            case Field.identityJudgement:
                self = .identityJudgement
            case Field.cancelProxy:
                self = .cancelProxy
            case Field.auction:
                self = .auction
            default:
                self = .other(rawType)
            }
        }

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            self.init(rawType: type)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case .any:
                try container.encode(Field.any)
            case .nonTransfer:
                try container.encode(Field.nonTransfer)
            case .governance:
                try container.encode(Field.governance)
            case .staking:
                try container.encode(Field.staking)
            case .nominationPools:
                try container.encode(Field.nominationPools)
            case .identityJudgement:
                try container.encode(Field.identityJudgement)
            case .cancelProxy:
                try container.encode(Field.cancelProxy)
            case .auction:
                try container.encode(Field.auction)
            case let .other(type):
                try container.encode(type)
            }

            try container.encode(JSON.null)
        }

        var allowStaking: Bool {
            switch self {
            case .any, .nonTransfer, .staking:
                return true
            case .governance,
                 .nominationPools,
                 .identityJudgement,
                 .cancelProxy,
                 .auction,
                 .other:
                return false
            }
        }
    }
}
