import Foundation
import SubstrateSdk
import BigInt

extension ParachainStaking {
    struct DelegateCall: Codable {
        enum CodingKeys: String, CodingKey {
            case candidate
            case amount
            case candidateDelegationCount = "candidate_delegation_count"
            case delegationCount = "delegation_count"
        }

        @BytesCodable var candidate: AccountId
        @StringCodable var amount: BigUInt
        @StringCodable var candidateDelegationCount: UInt32
        @StringCodable var delegationCount: UInt32
    }
}

extension ParachainStaking.DelegateCall {
    var extrinsicIdentifier: String {
        candidate.toHex() + "-"
            + String(amount) + "-"
            + String(candidateDelegationCount) + "-"
            + String(delegationCount)
    }

    var runtimeCall: RuntimeCall<ParachainStaking.DelegateCall> {
        RuntimeCall(moduleName: "ParachainStaking", callName: "delegate", args: self)
    }
}
