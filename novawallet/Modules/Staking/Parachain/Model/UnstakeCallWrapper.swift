import Foundation
import BigInt
import SubstrateSdk

struct UnstakeCallWrapper {
    let collator: AccountId
    let amount: BigUInt?

    func extrinsicId() -> String {
        collator.toHex() + "-" + String(amount ?? 0)
    }

    func accept(builder: ExtrinsicBuilderProtocol) throws -> ExtrinsicBuilderProtocol {
        if let amount = amount {
            let call = ParachainStaking.ScheduleBondLessCall(candidate: collator, less: amount)

            return try builder.adding(call: call.runtimeCall)
        } else {
            let call = ParachainStaking.ScheduleRevokeCall(collator: collator)

            return try builder.adding(call: call.runtimeCall)
        }
    }
}
