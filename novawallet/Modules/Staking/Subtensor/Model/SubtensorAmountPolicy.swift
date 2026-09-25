import BigInt
import Foundation

struct SubtensorSellPlanInput {
    let requestedAlpha: Balance
    let positionAlpha: Balance
    let availability: SubtensorStakingPallet.StakeAvailability
    let minimumTaoOut: Balance
    let sellLimitPrice: Balance
    let isOwnHotkey: Bool
    let minStake: Balance
    let nominatorMinStake: Balance
}

struct SubtensorRootMaxUnstakeInput {
    let hotkey: AccountId
    let positionAlpha: Balance
    let availability: SubtensorStakingPallet.StakeAvailability
    let transferable: Balance
    let networkFee: Balance
    let isOwnHotkey: Bool
    let minStake: Balance
    let nominatorMinStake: Balance
}

enum SubtensorAmountPolicy {
    static func maxBuyOrStake(transferable: Balance, networkFee: Balance) -> Balance {
        let retained = networkFee + SubtensorNovaFeeConstants.feeReserve

        return transferable > retained ? transferable - retained : 0
    }

    static func canPayBatchedSell(
        transferable: Balance,
        networkFee: Balance,
        existentialDeposit: Balance
    ) -> Bool {
        transferable >= networkFee + existentialDeposit
    }

    static func maxSell(
        positionAlpha: Balance,
        availability: SubtensorStakingPallet.StakeAvailability
    ) -> Balance {
        min(positionAlpha, availability.available)
    }

    static func sellPlan(for input: SubtensorSellPlanInput) -> SubtensorSellPlan {
        let maxSellable = maxSell(positionAlpha: input.positionAlpha, availability: input.availability)

        guard input.requestedAlpha <= maxSellable else {
            return .exceedsAvailable
        }

        guard input.requestedAlpha < input.positionAlpha else {
            return .sellAll
        }

        guard input.minimumTaoOut >= input.minStake else {
            return .belowMinimumOut
        }

        guard !input.isOwnHotkey else {
            return .partial
        }

        let remainder = input.positionAlpha - input.requestedAlpha
        let remainderValue = remainder * input.sellLimitPrice / SubtensorStakingPallet.alphaPriceScale

        guard remainderValue < input.nominatorMinStake else {
            return .partial
        }

        let isRemainderFullyAvailable = input.availability.available >= input.positionAlpha

        return isRemainderFullyAvailable ? .remainderWouldBeSwept : .remainderWouldBeErased
    }

    static func rootMaxUnstake(for input: SubtensorRootMaxUnstakeInput) -> SubtensorStakingOperation? {
        guard input.positionAlpha > 0 else {
            return nil
        }

        guard input.transferable >= input.networkFee else {
            let isPositionFullyAvailable = input.availability.available >= input.positionAlpha

            return isPositionFullyAvailable ? .rootUnstakeAll(hotkey: input.hotkey) : nil
        }

        let amount = maxSell(positionAlpha: input.positionAlpha, availability: input.availability)

        let plan = sellPlan(
            for: SubtensorSellPlanInput(
                requestedAlpha: amount,
                positionAlpha: input.positionAlpha,
                availability: input.availability,
                minimumTaoOut: amount,
                sellLimitPrice: SubtensorStakingPallet.alphaPriceScale,
                isOwnHotkey: input.isOwnHotkey,
                minStake: input.minStake,
                nominatorMinStake: input.nominatorMinStake
            )
        )

        switch plan {
        case .sellAll, .partial:
            return .rootUnstake(hotkey: input.hotkey, amount: amount)
        case .exceedsAvailable, .belowMinimumOut, .remainderWouldBeSwept, .remainderWouldBeErased:
            return nil
        }
    }
}
