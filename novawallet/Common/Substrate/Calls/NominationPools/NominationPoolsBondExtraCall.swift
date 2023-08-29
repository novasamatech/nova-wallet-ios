import Foundation
import SubstrateSdk
import BigInt

extension NominationPools {
    struct BondExtraCall: Codable {
        enum SourceType: Codable {
            static let freeBalanceField = "FreeBalance"
            static let rewardsField = "Rewards"

            case freeBalance(BigUInt)
            case rewards

            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()

                let type = try container.decode(String.self)

                switch type {
                case Self.freeBalanceField:
                    let balance = try container.decode(StringScaleMapper<BigUInt>.self).value
                    self = .freeBalance(balance)
                case Self.rewardsField:
                    self = .rewards
                default:
                    throw DecodingError.dataCorrupted(
                        .init(codingPath: decoder.codingPath, debugDescription: "Unsupported \(type)")
                    )
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()

                switch self {
                case let .freeBalance(balance):
                    try container.encode(Self.freeBalanceField)
                    try container.encode(StringScaleMapper(value: balance))
                case .rewards:
                    try container.encode(Self.rewards)
                }
            }
        }

        let extra: SourceType

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(moduleName: NominationPools.module, callName: "bond_extra", args: self)
        }
    }
}
