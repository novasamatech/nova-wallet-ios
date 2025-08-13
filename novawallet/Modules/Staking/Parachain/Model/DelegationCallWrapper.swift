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

    func accept(
        builder: ExtrinsicBuilderProtocol,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        if existingBond != nil {
            return try acceptForStakeMore(builder: builder)
        } else {
            return try acceptForStartStaking(
                builder: builder,
                codingFactory: codingFactory
            )
        }
    }
}

private extension DelegationCallWrapper {
    func acceptForStartStaking(
        builder: ExtrinsicBuilderProtocol,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        if codingFactory.hasCall(
            for: ParachainStaking.DelegateWithAutocompoundCall.callCodingPath
        ) {
            // we currently don't support auto compound in ui
            let call = ParachainStaking.DelegateWithAutocompoundCall(
                candidate: collator,
                amount: amount,
                autoCompound: 0,
                candidateDelegationCount: collatorDelegationsCount,
                candidateAutoCompoundingDelegationCount: 0,
                delegationCount: delegationsCount
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

    func acceptForStakeMore(
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        let call = ParachainStaking.DelegatorBondMoreCall(
            candidate: collator,
            more: amount
        )

        return try builder.adding(call: call.runtimeCall)
    }
}
