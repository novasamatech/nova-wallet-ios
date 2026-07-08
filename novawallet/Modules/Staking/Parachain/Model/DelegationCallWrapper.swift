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
            return try acceptForStakeMore(builder: builder, codingFactory: codingFactory)
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
        // EWX (AvN fork) uses "nominate" with nomination-count params
        if codingFactory.hasCall(for: ParachainAvn.NominateCall.callCodingPath) {
            let call = ParachainAvn.NominateCall(
                candidate: collator,
                amount: amount,
                candidateNominationCount: collatorDelegationsCount,
                nominationCount: delegationsCount
            )

            return try builder.adding(call: call.runtimeCall)
        } else if codingFactory.hasCall(
            for: ParachainStaking.DelegateWithAutocompoundCall.callCodingPath
        ) {
            // Moonbeam with auto-compound
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
            // Moonbeam legacy delegate
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
        builder: ExtrinsicBuilderProtocol,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        // EWX (AvN fork) uses "bond_extra"
        if codingFactory.hasCall(for: ParachainAvn.BondExtraCall.callCodingPath) {
            let call = ParachainAvn.BondExtraCall(
                candidate: collator,
                more: amount
            )

            return try builder.adding(call: call.runtimeCall)
        } else {
            let call = ParachainStaking.DelegatorBondMoreCall(
                candidate: collator,
                more: amount
            )

            return try builder.adding(call: call.runtimeCall)
        }
    }
}
