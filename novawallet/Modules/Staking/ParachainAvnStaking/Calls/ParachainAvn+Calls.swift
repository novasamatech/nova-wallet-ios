import Foundation
import SubstrateSdk
import BigInt

/// Substrate call structs for Energy Web X's `ParachainStaking` pallet
/// (Aventus AvN fork). Each call mirrors the on-chain SCALE name exactly
/// — verified against EWX mainnet runtime metadata v15 (spec version 105,
/// 2026-04-11) via `state_getMetadata`.
///
/// EWX kept the pre-rename API that Moonbeam later migrated away from:
///
///   EWX (this file)                    Moonbeam (ParaStkCalls.swift)
///   -----------------                   -----------------------------
///   nominate                            delegate
///   bond_extra                          delegator_bond_more
///   schedule_nominator_unbond           schedule_delegator_bond_less
///   schedule_revoke_nomination          schedule_revoke_delegation
///   execute_nomination_request          execute_delegation_request
///   cancel_nomination_request           cancel_delegation_request
///
/// Do NOT refactor to share code with `ParaStkCalls.swift`. The call
/// names differ, and so does the parameter naming inside most calls
/// (e.g. `candidate_nomination_count` vs `candidate_delegation_count`).
extension ParachainAvn {
    /// `parachainStaking.nominate(candidate, amount, candidate_nomination_count, nomination_count)`
    ///
    /// First-time nomination of a collator. The two `*_count` fields
    /// are required by the pallet to pre-validate storage iteration
    /// costs: `candidate_nomination_count` is the current nominator
    /// count on the target candidate (read from `candidateInfo`),
    /// `nomination_count` is how many nominations the caller already
    /// holds (read from `nominatorState`).
    struct NominateCall: Codable {
        enum CodingKeys: String, CodingKey {
            case candidate
            case amount
            case candidateNominationCount = "candidate_nomination_count"
            case nominationCount = "nomination_count"
        }

        @BytesCodable var candidate: AccountId
        @StringCodable var amount: BigUInt
        @StringCodable var candidateNominationCount: UInt32
        @StringCodable var nominationCount: UInt32
    }

    /// `parachainStaking.bond_extra(candidate, more)`
    ///
    /// Increases an existing nomination by `more` wei.
    struct BondExtraCall: Codable {
        enum CodingKeys: String, CodingKey {
            case candidate
            case more
        }

        @BytesCodable var candidate: AccountId
        @StringCodable var more: BigUInt
    }

    /// `parachainStaking.schedule_nominator_unbond(candidate, less)`
    ///
    /// Schedules a partial unbond that becomes executable after the
    /// `ParachainStaking.Delay` storage value (currently ~2 eras).
    struct ScheduleNominatorUnbondCall: Codable {
        enum CodingKeys: String, CodingKey {
            case candidate
            case less
        }

        @BytesCodable var candidate: AccountId
        @StringCodable var less: BigUInt
    }

    /// `parachainStaking.schedule_revoke_nomination(collator)`
    ///
    /// Schedules a full revoke of a nomination on the given collator.
    /// Executable after the same delay as a partial unbond.
    struct ScheduleRevokeNominationCall: Codable {
        enum CodingKeys: String, CodingKey {
            case collator
        }

        @BytesCodable var collator: AccountId
    }

    /// `parachainStaking.execute_nomination_request(nominator, candidate)`
    ///
    /// Executes a previously-scheduled unbond or revoke after the delay
    /// has elapsed. Any account can call this — it's not self-service.
    struct ExecuteNominationRequestCall: Codable {
        enum CodingKeys: String, CodingKey {
            case nominator
            case candidate
        }

        @BytesCodable var nominator: AccountId
        @BytesCodable var candidate: AccountId
    }

    /// `parachainStaking.cancel_nomination_request(candidate)`
    ///
    /// Cancels a previously-scheduled unbond or revoke before it has
    /// been executed.
    struct CancelNominationRequestCall: Codable {
        enum CodingKeys: String, CodingKey {
            case candidate
        }

        @BytesCodable var candidate: AccountId
    }
}

// MARK: - RuntimeCall wrappers

extension ParachainAvn.NominateCall {
    static var callCodingPath: CallCodingPath {
        CallCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            callName: "nominate"
        )
    }

    var runtimeCall: RuntimeCall<Self> {
        RuntimeCall(
            moduleName: Self.callCodingPath.moduleName,
            callName: Self.callCodingPath.callName,
            args: self
        )
    }
}

extension ParachainAvn.BondExtraCall {
    static var callCodingPath: CallCodingPath {
        CallCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            callName: "bond_extra"
        )
    }

    var runtimeCall: RuntimeCall<Self> {
        RuntimeCall(
            moduleName: Self.callCodingPath.moduleName,
            callName: Self.callCodingPath.callName,
            args: self
        )
    }
}

extension ParachainAvn.ScheduleNominatorUnbondCall {
    static var callCodingPath: CallCodingPath {
        CallCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            callName: "schedule_nominator_unbond"
        )
    }

    var runtimeCall: RuntimeCall<Self> {
        RuntimeCall(
            moduleName: Self.callCodingPath.moduleName,
            callName: Self.callCodingPath.callName,
            args: self
        )
    }
}

extension ParachainAvn.ScheduleRevokeNominationCall {
    static var callCodingPath: CallCodingPath {
        CallCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            callName: "schedule_revoke_nomination"
        )
    }

    var runtimeCall: RuntimeCall<Self> {
        RuntimeCall(
            moduleName: Self.callCodingPath.moduleName,
            callName: Self.callCodingPath.callName,
            args: self
        )
    }
}

extension ParachainAvn.ExecuteNominationRequestCall {
    static var callCodingPath: CallCodingPath {
        CallCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            callName: "execute_nomination_request"
        )
    }

    var runtimeCall: RuntimeCall<Self> {
        RuntimeCall(
            moduleName: Self.callCodingPath.moduleName,
            callName: Self.callCodingPath.callName,
            args: self
        )
    }
}

extension ParachainAvn.CancelNominationRequestCall {
    static var callCodingPath: CallCodingPath {
        CallCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            callName: "cancel_nomination_request"
        )
    }

    var runtimeCall: RuntimeCall<Self> {
        RuntimeCall(
            moduleName: Self.callCodingPath.moduleName,
            callName: Self.callCodingPath.callName,
            args: self
        )
    }
}
