import Foundation
import SubstrateSdk

extension MythosStakingPallet {
    struct LockCall: Codable {
        @StringCodable var amount: Balance

        func runtimeCall() -> RuntimeCall<Self> {
            .init(moduleName: MythosStakingPallet.name, callName: "lock", args: self)
        }
    }

    struct StakeTarget: Codable {
        @BytesCodable var candidate: AccountId
        @StringCodable var stake: Balance
    }

    struct StakeCall: Codable {
        let targets: [StakeTarget]

        func runtimeCall() -> RuntimeCall<Self> {
            .init(moduleName: MythosStakingPallet.name, callName: "stake", args: self)
        }
    }
}
