import Foundation
import SubstrateSdk

extension NominationPools {
    struct ClaimRewardsCall: Codable {
        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(moduleName: NominationPools.module, callName: "claim_payout", args: self)
        }
    }
}
