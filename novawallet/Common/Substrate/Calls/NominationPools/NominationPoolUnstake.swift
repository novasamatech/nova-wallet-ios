import Foundation
import SubstrateSdk
import BigInt

extension NominationPools {
    struct UnbondCall: Codable {
        enum CodingKeys: String, CodingKey {
            case memberAccount = "member_account"
            case unbondingPoints = "unbonding_points"
        }

        let memberAccount: MultiAddress
        @StringCodable var unbondingPoints: BigUInt

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(moduleName: NominationPools.module, callName: "unbond", args: self)
        }
    }
}
