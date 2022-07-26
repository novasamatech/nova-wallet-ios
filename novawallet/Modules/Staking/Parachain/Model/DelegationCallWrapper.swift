import Foundation
import BigInt
import SubstrateSdk

struct DelegationCallWrapper {
    let amount: BigUInt
    let collator: AccountId
    let collatorDelegationsCount: UInt32
    let delegationsCount: UInt32
    let existingBond: BigUInt?

    func extrinsicId() -> String {
        collator.toHex() + "-"
            + String(amount) + "-"
            + String(collatorDelegationsCount) + "-"
            + String(delegationsCount)
    }

    func accept(builder: ExtrinsicBuilderProtocol) throws -> ExtrinsicBuilderProtocol {
        if existingBond != nil {
            let call = ParachainStaking.DelegatorBondMoreCall(
                candidate: collator,
                more: amount
            )

            return try builder.adding(call: call.runtimeCall)
        } else {
            let call = ParachainStaking.DelegateCall(
                candidate: collator,
                amount: amount,
                candidateDelegationCount: collatorDelegationsCount,
                delegationCount: delegationsCount
            )

            return try builder.adding(call: call.runtimeCall)
        }
    }
}
