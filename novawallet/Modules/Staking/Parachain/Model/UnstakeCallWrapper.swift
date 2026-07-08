import Foundation
import BigInt
import SubstrateSdk

struct UnstakeCallWrapper {
    enum Action {
        case bondLess(amount: BigUInt)
        case revoke(amount: BigUInt)
    }

    let collator: AccountId
    let action: UnstakeCallWrapper.Action

    func extrinsicId() -> String {
        switch action {
        case let .bondLess(amount):
            return collator.toHex() + "-" + String(amount)
        case .revoke:
            return collator.toHex() + "-" + "revoke"
        }
    }

    func accept(
        builder: ExtrinsicBuilderProtocol,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        // Probe each EWX (AvN-fork) call independently — mirrors the per-call
        // pattern in `DelegationCallWrapper`. If a future runtime renames or
        // splits the two calls we don't want to silently dispatch a missing one.
        switch action {
        case let .bondLess(amount):
            if codingFactory.hasCall(for: ParachainAvn.ScheduleNominatorUnbondCall.callCodingPath) {
                let call = ParachainAvn.ScheduleNominatorUnbondCall(candidate: collator, less: amount)
                return try builder.adding(call: call.runtimeCall)
            }

            let call = ParachainStaking.ScheduleBondLessCall(candidate: collator, less: amount)
            return try builder.adding(call: call.runtimeCall)

        case .revoke:
            if codingFactory.hasCall(for: ParachainAvn.ScheduleRevokeNominationCall.callCodingPath) {
                let call = ParachainAvn.ScheduleRevokeNominationCall(collator: collator)
                return try builder.adding(call: call.runtimeCall)
            }

            let call = ParachainStaking.ScheduleRevokeCall(collator: collator)
            return try builder.adding(call: call.runtimeCall)
        }
    }
}
