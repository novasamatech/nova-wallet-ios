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

    struct DelegatorBondMoreCall: Codable {
        enum CodingKeys: String, CodingKey {
            case candidate
            case more
        }

        @BytesCodable var candidate: AccountId
        @StringCodable var more: BigUInt
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

extension ParachainStaking.DelegatorBondMoreCall {
    var extrinsicIdentifier: String {
        candidate.toHex() + "-" + String(more)
    }

    var runtimeCall: RuntimeCall<ParachainStaking.DelegatorBondMoreCall> {
        RuntimeCall(moduleName: "ParachainStaking", callName: "delegator_bond_more", args: self)
    }
}
