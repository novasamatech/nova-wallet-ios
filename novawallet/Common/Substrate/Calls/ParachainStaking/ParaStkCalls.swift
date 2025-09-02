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

    struct DelegateWithAutocompoundCall: Codable {
        enum CodingKeys: String, CodingKey {
            case candidate
            case amount
            case autoCompound = "auto_compound"
            case candidateDelegationCount = "candidate_delegation_count"
            case candidateAutoCompoundingDelegationCount = "candidate_auto_compounding_delegation_count"
            case delegationCount = "delegation_count"
        }

        @BytesCodable var candidate: AccountId
        @StringCodable var amount: BigUInt
        @StringCodable var autoCompound: BigUInt
        @StringCodable var candidateDelegationCount: UInt32
        @StringCodable var candidateAutoCompoundingDelegationCount: UInt32
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

    struct ScheduleBondLessCall: Codable {
        enum CodingKeys: String, CodingKey {
            case candidate
            case less
        }

        @BytesCodable var candidate: AccountId
        @StringCodable var less: BigUInt

        var runtimeCall: RuntimeCall<ScheduleBondLessCall> {
            RuntimeCall(moduleName: "ParachainStaking", callName: "schedule_delegator_bond_less", args: self)
        }
    }

    struct ScheduleRevokeCall: Codable {
        enum CodingKeys: String, CodingKey {
            case collator
        }

        @BytesCodable var collator: AccountId

        var runtimeCall: RuntimeCall<ScheduleRevokeCall> {
            RuntimeCall(moduleName: "ParachainStaking", callName: "schedule_revoke_delegation", args: self)
        }
    }

    struct ExecuteDelegatorRequest: Codable {
        enum CodingKeys: String, CodingKey {
            case delegator
            case candidate
        }

        @BytesCodable var delegator: AccountId
        @BytesCodable var candidate: AccountId

        var runtimeCall: RuntimeCall<ExecuteDelegatorRequest> {
            RuntimeCall(moduleName: "ParachainStaking", callName: "execute_delegation_request", args: self)
        }
    }

    struct CancelDelegatorRequest: Codable {
        enum CodingKeys: String, CodingKey {
            case candidate
        }

        @BytesCodable var candidate: AccountId

        var runtimeCall: RuntimeCall<CancelDelegatorRequest> {
            RuntimeCall(moduleName: "ParachainStaking", callName: "cancel_delegation_request", args: self)
        }
    }
}

extension ParachainStaking.DelegateCall {
    static var callCodingPath: CallCodingPath {
        CallCodingPath(moduleName: "ParachainStaking", callName: "delegate")
    }

    var runtimeCall: RuntimeCall<Self> {
        RuntimeCall(
            moduleName: Self.callCodingPath.moduleName,
            callName: Self.callCodingPath.callName,
            args: self
        )
    }
}

extension ParachainStaking.DelegateWithAutocompoundCall {
    static var callCodingPath: CallCodingPath {
        CallCodingPath(moduleName: "ParachainStaking", callName: "delegate_with_auto_compound")
    }

    var runtimeCall: RuntimeCall<Self> {
        RuntimeCall(
            moduleName: Self.callCodingPath.moduleName,
            callName: Self.callCodingPath.callName,
            args: self
        )
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
