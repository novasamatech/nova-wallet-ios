import Foundation
import BigInt

struct SubtensorCommissionResult {
    /// Adds the Nova Wallet fee `transfer_keep_alive` leg to a builder. Caller controls order.
    let builderClosure: ExtrinsicBuilderClosure
    let commissionAmount: BigUInt
}

/// Nova service fee for Subtensor SUBNET staking. Root (netuid 0) and nil-recipient are no-ops.
enum SubtensorCommissionFactory {
    static func makeStakeCommission(
        gross: BigUInt,
        netuid: UInt16,
        feeAccountId: AccountId?,
        callFactory: SubstrateCallFactoryProtocol
    ) -> SubtensorCommissionResult? {
        makeCommission(gross: gross, netuid: netuid, feeAccountId: feeAccountId, callFactory: callFactory)
    }

    static func makeUnstakeCommission(
        minTaoOut: BigUInt,
        netuid: UInt16,
        feeAccountId: AccountId?,
        callFactory: SubstrateCallFactoryProtocol
    ) -> SubtensorCommissionResult? {
        makeCommission(gross: minTaoOut, netuid: netuid, feeAccountId: feeAccountId, callFactory: callFactory)
    }

    private static func makeCommission(
        gross: BigUInt,
        netuid: UInt16,
        feeAccountId: AccountId?,
        callFactory: SubstrateCallFactoryProtocol
    ) -> SubtensorCommissionResult? {
        guard netuid != SubtensorStakingConstants.rootNetuid else { return nil }
        guard let feeAccountId else { return nil }
        let fee = SubtensorStakingConstants.novaFeeAmount(from: gross)
        guard fee > 0 else { return nil }
        let transfer = callFactory.nativeTransfer(to: feeAccountId, amount: fee, callPath: .transferKeepAlive)
        let closure: ExtrinsicBuilderClosure = { builder in try builder.adding(call: transfer) }
        return SubtensorCommissionResult(builderClosure: closure, commissionAmount: fee)
    }
}
