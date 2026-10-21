import Foundation

extension SubtensorStakeSetupPresenter {
    var eligibleShieldQuote: SubtensorShieldQuote? {
        let input = SubtensorShieldEligibilityInput(
            walletType: selectedAccount.chainAccount.type,
            quote: shieldQuote,
            transferable: transferable,
            existentialDeposit: existentialDeposit
        )

        return SubtensorShieldEligibility.isEligible(input) ? shieldQuote : nil
    }

    var maxAmount: Balance? {
        guard let transferable, let fee else {
            return nil
        }

        let networkFee = eligibleShieldQuote?.totalFee.amount ?? fee.amountForCurrentAccount ?? 0

        return SubtensorAmountPolicy.maxBuyOrStake(transferable: transferable, networkFee: networkFee)
    }
}
