import Foundation
import SubstrateSdk

enum SubtensorStakingCallModel {
    case stake(SubtensorStakeModel)
    case unstake(SubtensorUnstakeModel, limitPrice: Balance? = nil)
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
        case let .unstake(model, limitPrice):
            guard model.netuid == SubtensorStakingPallet.rootNetuid || limitPrice != nil else {
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
            case let .unstake(model, limitPrice) where model.isFullUnstake:
                let call = SubtensorStakingPallet.RemoveStakeFullLimitCall(
                    hotkey: model.hotkey,
                    netuid: model.netuid,
                    limitPrice: limitPrice
                )

                return try builder.adding(call: call.runtimeCall())
            case let .unstake(model, limitPrice):
                if let limitPrice {
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
