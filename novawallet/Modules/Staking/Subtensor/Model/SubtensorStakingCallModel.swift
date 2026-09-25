import Foundation
import SubstrateSdk

enum SubtensorStakingCallModel {
    case stake(SubtensorStakeModel)
    case unstake(SubtensorUnstakeModel)
    case claim(hotkey: AccountId)
}

enum SubtensorStakingCallModelError: Error {
    case unprotectedSubnetOrder(netuid: UInt16)
}

extension SubtensorStakingCallModel {
    /// fee estimation may legitimately run before a subnet quote exists, so the
    /// limit-price requirement is enforced only at submission
    func ensureSlippageProtected() throws {
        switch self {
        case let .stake(model):
            guard model.netuid == SubtensorStakingPallet.rootNetuid || model.limitPrice != nil else {
                throw SubtensorStakingCallModelError.unprotectedSubnetOrder(netuid: model.netuid)
            }
        case let .unstake(model):
            guard model.netuid == SubtensorStakingPallet.rootNetuid || model.limitPrice != nil else {
                throw SubtensorStakingCallModelError.unprotectedSubnetOrder(netuid: model.netuid)
            }
        case .claim:
            break
        }
    }

    var extrinsicBuilderClosure: ExtrinsicBuilderClosure {
        { builder in
            switch self {
            case let .stake(model):
                if let limitPrice = model.limitPrice {
                    // fill-or-kill always: a clamped partial fill would be indistinguishable
                    // from success without event diffing
                    let call = SubtensorStakingPallet.AddStakeLimitCall(
                        hotkey: model.hotkey,
                        netuid: model.netuid,
                        amountStaked: model.amount,
                        limitPrice: limitPrice,
                        allowPartial: false
                    )

                    return try builder.adding(call: call.runtimeCall())
                } else {
                    let call = SubtensorStakingPallet.AddStakeCall(
                        hotkey: model.hotkey,
                        netuid: model.netuid,
                        amountStaked: model.amount
                    )

                    return try builder.adding(call: call.runtimeCall())
                }
            case let .unstake(model) where model.isFullUnstake:
                let call = SubtensorStakingPallet.RemoveStakeFullLimitCall(
                    hotkey: model.hotkey,
                    netuid: model.netuid,
                    limitPrice: model.limitPrice
                )

                return try builder.adding(call: call.runtimeCall())
            case let .unstake(model):
                if let limitPrice = model.limitPrice {
                    let call = SubtensorStakingPallet.RemoveStakeLimitCall(
                        hotkey: model.hotkey,
                        netuid: model.netuid,
                        amountUnstaked: model.amount,
                        limitPrice: limitPrice,
                        allowPartial: false
                    )

                    return try builder.adding(call: call.runtimeCall())
                } else {
                    let call = SubtensorStakingPallet.RemoveStakeCall(
                        hotkey: model.hotkey,
                        netuid: model.netuid,
                        amountUnstaked: model.amount
                    )

                    return try builder.adding(call: call.runtimeCall())
                }
            case let .claim(hotkey):
                let call = SubtensorStakingPallet.ClaimRootWithHotkeyCall(hotkey: hotkey)

                return try builder.adding(call: call.runtimeCall())
            }
        }
    }
}

extension SubtensorStakingOperation {
    func ensureLimitPolicy() throws {
        switch self {
        case .rootStake, .rootUnstake, .rootUnstakeAll, .claimRoot:
            return
        case let .subnetBuy(_, netuid, _, limitPrice),
             let .subnetSell(_, netuid, _, limitPrice),
             let .subnetSellAll(_, netuid, _, limitPrice):
            guard netuid != SubtensorStakingPallet.rootNetuid else {
                throw SubtensorStakingOperationError.limitOnRootOrder
            }

            guard limitPrice > 0 else {
                throw SubtensorStakingOperationError.unprotectedSubnetOrder
            }
        }
    }

    func extrinsicBuilderClosure(
        feeCalculator: SubtensorNovaFeeCalculator
    ) throws -> ExtrinsicBuilderClosure {
        try ensureLimitPolicy()

        let novaFee = try feeCalculator.novaFee(for: self)
        let stakingClosure = try createStakingCallClosure(novaFeeAmount: novaFee?.amount ?? 0)

        guard let novaFee else {
            return stakingClosure
        }

        let feeTransfer = SubstrateCallFactory().nativeTransfer(
            to: novaFee.beneficiary,
            amount: novaFee.amount,
            callPath: .transferKeepAlive
        )

        return { builder in
            try stakingClosure(builder.with(batchType: .atomic)).adding(call: feeTransfer)
        }
    }
}

private extension SubtensorStakingOperation {
    static func addingClosure<T: Codable>(_ call: RuntimeCall<T>) -> ExtrinsicBuilderClosure {
        { builder in
            try builder.adding(call: call)
        }
    }

    func createStakingCallClosure(novaFeeAmount: Balance) throws -> ExtrinsicBuilderClosure {
        let rootNetuid = SubtensorStakingPallet.rootNetuid

        switch self {
        case let .rootStake(hotkey, amount):
            return try Self.addingClosure(
                SubtensorStakingPallet.AddStakeCall(hotkey: hotkey, netuid: rootNetuid, amountStaked: amount)
                    .runtimeCall()
            )
        case let .rootUnstake(hotkey, amount):
            return try Self.addingClosure(
                SubtensorStakingPallet.RemoveStakeCall(hotkey: hotkey, netuid: rootNetuid, amountUnstaked: amount)
                    .runtimeCall()
            )
        case let .rootUnstakeAll(hotkey):
            return try Self.addingClosure(
                SubtensorStakingPallet.RemoveStakeFullLimitCall(hotkey: hotkey, netuid: rootNetuid, limitPrice: nil)
                    .runtimeCall()
            )
        case let .subnetBuy(hotkey, netuid, grossTao, limitPrice):
            return try Self.addingClosure(
                SubtensorStakingPallet.AddStakeLimitCall(
                    hotkey: hotkey,
                    netuid: netuid,
                    amountStaked: grossTao > novaFeeAmount ? grossTao - novaFeeAmount : 0,
                    limitPrice: limitPrice,
                    allowPartial: false
                ).runtimeCall()
            )
        case let .subnetSell(hotkey, netuid, alpha, limitPrice):
            return try Self.addingClosure(
                SubtensorStakingPallet.RemoveStakeLimitCall(
                    hotkey: hotkey,
                    netuid: netuid,
                    amountUnstaked: alpha,
                    limitPrice: limitPrice,
                    allowPartial: false
                ).runtimeCall()
            )
        case let .subnetSellAll(hotkey, netuid, _, limitPrice):
            return try Self.addingClosure(
                SubtensorStakingPallet.RemoveStakeFullLimitCall(hotkey: hotkey, netuid: netuid, limitPrice: limitPrice)
                    .runtimeCall()
            )
        case let .claimRoot(hotkey):
            return Self.addingClosure(SubtensorStakingPallet.ClaimRootWithHotkeyCall(hotkey: hotkey).runtimeCall())
        }
    }
}
