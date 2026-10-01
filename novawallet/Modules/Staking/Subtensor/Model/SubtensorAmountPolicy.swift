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
}
