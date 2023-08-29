import Foundation
import SubstrateSdk
import BigInt

extension NominationPools {
    struct BondExtraCall: Codable {
        let extra: BondExtraOption

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(moduleName: "NominationPools", callName: "bond_extra", args: self)
        }
    }

    enum BondExtraOption: Codable {
        static let freeBalanceField = "FreeBalance"
        static let rewardsField = "Rewards"

        case freeBalance(BigUInt)
        case rewards

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .freeBalance(amount):
                try container.encode(BondExtraOption.freeBalanceField)
                try container.encode(StringScaleMapper(value: amount))
            case .rewards:
                try container.encode(BondExtraOption.rewardsField)
                try container.encode(JSON.null)
            }
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            switch try container.decode(String.self) {
            case BondExtraOption.freeBalanceField:
                let amount = try container.decode(StringScaleMapper<BigUInt>.self).value
                self = .freeBalance(amount)
            case BondExtraOption.rewardsField:
                self = .rewards
            default:
                throw CommonError.dataCorruption
            }
        }
    }
}
