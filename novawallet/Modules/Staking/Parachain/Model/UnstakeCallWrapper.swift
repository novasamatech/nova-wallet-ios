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

    func accept(builder: ExtrinsicBuilderProtocol) throws -> ExtrinsicBuilderProtocol {
        switch action {
        case let .bondLess(amount):
            let call = ParachainStaking.ScheduleBondLessCall(candidate: collator, less: amount)

            return try builder.adding(call: call.runtimeCall)
        case .revoke:
            let call = ParachainStaking.ScheduleRevokeCall(collator: collator)

            return try builder.adding(call: call.runtimeCall)
        }
    }
}
