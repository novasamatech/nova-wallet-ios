import Foundation

enum SubtensorStakingCallModel {
    case stake(SubtensorStakeModel)
    case unstake(SubtensorUnstakeModel)
    case claim(hotkey: AccountId)
}

extension SubtensorStakingCallModel {
    var extrinsicBuilderClosure: ExtrinsicBuilderClosure {
        { builder in
            switch self {
            case let .stake(model):
                let call = SubtensorStakingPallet.AddStakeCall(
                    hotkey: model.hotkey,
                    netuid: model.netuid,
                    amountStaked: model.amount
                )

                return try builder.adding(call: call.runtimeCall())
            case let .unstake(model) where model.isFullUnstake:
                let call = SubtensorStakingPallet.RemoveStakeFullLimitCall(
                    hotkey: model.hotkey,
                    netuid: model.netuid,
                    limitPrice: nil
                )

                return try builder.adding(call: call.runtimeCall())
            case let .unstake(model):
                let call = SubtensorStakingPallet.RemoveStakeCall(
                    hotkey: model.hotkey,
                    netuid: model.netuid,
                    amountUnstaked: model.amount
                )

                return try builder.adding(call: call.runtimeCall())
            case let .claim(hotkey):
                let call = SubtensorStakingPallet.ClaimRootWithHotkeyCall(hotkey: hotkey)

                return try builder.adding(call: call.runtimeCall())
            }
        }
    }
}
