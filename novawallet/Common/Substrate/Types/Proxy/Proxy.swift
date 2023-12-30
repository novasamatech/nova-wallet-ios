import Foundation
import SubstrateSdk
import BigInt

enum Proxy {
    static var moduleName: String {
        "proxy"
    }

    struct ProxyDefinition: Decodable {
        enum CodingKeys: String, CodingKey {
            case proxy = "delegate"
            case proxyType
            case delay
        }

        @BytesCodable var proxy: AccountId
        let proxyType: ProxyType
        @StringCodable var delay: BlockNumber
    }

    enum ProxyType: Hashable, Decodable {
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
            case Field.nominationPools:
                self = .nominationPools
            case Field.identityJudgement:
                self = .identityJudgement
            case Field.cancelProxy:
                self = .cancelProxy
            case Field.auction:
                self = .auction
            default:
                self = .other(type)
            }
        }
    }
}
