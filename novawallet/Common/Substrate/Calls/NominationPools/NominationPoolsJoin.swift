import Foundation
import SubstrateSdk
import BigInt

extension NominationPools {
    struct JoinCall: Codable {
        enum CodingKeys: String, CodingKey {
            case amount
            case poolId = "pool_id"
        }

        @StringCodable var amount: BigUInt
        @StringCodable var poolId: NominationPools.PoolId

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(moduleName: "NominationPools", callName: "join", args: self)
        }
    }
}
