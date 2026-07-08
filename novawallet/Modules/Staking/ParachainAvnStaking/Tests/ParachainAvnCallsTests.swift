import XCTest
import BigInt
@testable import novawallet

/// Verifies that every `ParachainAvn` call struct emits the exact
/// SCALE call name the Energy Web X runtime expects. EWX inherits
/// Aventus's pre-rename API, not Moonbeam's post-rename one — if any
/// of these tests break because someone "unified" the call types with
/// `ParachainStaking.*Call` in `ParaStkCalls.swift`, the resulting
/// extrinsics will be rejected on-chain with an invalid-call decoding
/// error.
///
/// Call names verified against EWX mainnet metadata v15 (spec version
/// 105, 2026-04-11).
final class ParachainAvnCallsTests: XCTestCase {
    private let stubAccountId = AccountId(repeating: 0xAB, count: 32)
    private let otherStubAccountId = AccountId(repeating: 0xCD, count: 32)
    private let oneEwt: BigUInt = 1_000_000_000_000_000_000

    func test_nominateCall_usesAvnCallName() {
        let call = ParachainAvn.NominateCall(
            candidate: stubAccountId,
            amount: oneEwt,
            candidateNominationCount: 42,
            nominationCount: 0
        )
        let runtimeCall = call.runtimeCall
        XCTAssertEqual(runtimeCall.moduleName, "ParachainStaking")
        XCTAssertEqual(runtimeCall.callName, "nominate")
    }

    func test_bondExtraCall_usesAvnCallName() {
        let call = ParachainAvn.BondExtraCall(candidate: stubAccountId, more: oneEwt)
        XCTAssertEqual(call.runtimeCall.moduleName, "ParachainStaking")
        XCTAssertEqual(call.runtimeCall.callName, "bond_extra")
    }

    func test_scheduleNominatorUnbondCall_usesAvnCallName() {
        let call = ParachainAvn.ScheduleNominatorUnbondCall(
            candidate: stubAccountId,
            less: oneEwt
        )
        XCTAssertEqual(call.runtimeCall.callName, "schedule_nominator_unbond")
    }

    func test_scheduleRevokeNominationCall_usesAvnCallName() {
        let call = ParachainAvn.ScheduleRevokeNominationCall(collator: stubAccountId)
        XCTAssertEqual(call.runtimeCall.callName, "schedule_revoke_nomination")
    }

    func test_executeNominationRequestCall_usesAvnCallName() {
        let call = ParachainAvn.ExecuteNominationRequestCall(
            nominator: stubAccountId,
            candidate: otherStubAccountId
        )
        XCTAssertEqual(call.runtimeCall.callName, "execute_nomination_request")
    }

    func test_cancelNominationRequestCall_usesAvnCallName() {
        let call = ParachainAvn.CancelNominationRequestCall(candidate: stubAccountId)
        XCTAssertEqual(call.runtimeCall.callName, "cancel_nomination_request")
    }
}
