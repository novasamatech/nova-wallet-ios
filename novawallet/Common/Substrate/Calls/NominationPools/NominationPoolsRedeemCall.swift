import Foundation
import SubstrateSdk

extension NominationPools {
    struct RedeemCall: Codable {
        enum CodingKeys: String, CodingKey {
            case memberAccount = "member_account"
            case numberOfSlashingSpans = "num_slashing_spans"
        }

        let memberAccount: MultiAddress
        @StringCodable var numberOfSlashingSpans: UInt32

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(moduleName: NominationPools.module, callName: "withdraw_unbonded", args: self)
        }
    }
}
