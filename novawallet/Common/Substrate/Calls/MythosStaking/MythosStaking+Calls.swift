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

    struct ClaimRewardsCall: Codable {
        func runtimeCall() -> RuntimeCall<Self> {
            .init(moduleName: MythosStakingPallet.name, callName: "claim_rewards", args: self)
        }
    }

    struct UnstakeCall: Codable {
        @BytesCodable var account: AccountId

        func runtimeCall() -> RuntimeCall<Self> {
            .init(moduleName: MythosStakingPallet.name, callName: "unstake_from", args: self)
        }
    }

    struct UnlockCall: Codable {
        enum CodingKeys: String, CodingKey {
            case maybeAmount = "maybe_amount"
        }

        @OptionStringCodable var maybeAmount: Balance?

        func runtimeCall() -> RuntimeCall<Self> {
            .init(moduleName: MythosStakingPallet.name, callName: "unlock", args: self)
        }
    }

    struct ReleaseCall: Codable {
        func runtimeCall() -> RuntimeCall<Self> {
            .init(moduleName: MythosStakingPallet.name, callName: "release", args: self)
        }
    }
}
