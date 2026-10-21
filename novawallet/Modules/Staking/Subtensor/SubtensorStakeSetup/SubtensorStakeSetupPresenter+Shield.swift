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

    var networkFee: ExtrinsicFeeProtocol? {
        guard isShieldQuoteResolved else {
            return nil
        }

        return eligibleShieldQuote?.totalFee ?? fee
    }

    var maxAmount: Balance? {
        guard let transferable, let networkFee else {
            return nil
        }

        return SubtensorAmountPolicy.maxBuyOrStake(
            transferable: transferable,
            networkFee: networkFee.amountForCurrentAccount ?? 0
        )
    }

    func resetShieldQuote() {
        shieldQuote = nil
        shieldQuoteOperation = nil
        isShieldQuoteResolved = false
        interactor.cancelShieldQuote()
    }

    func retryUnresolvedShieldQuote() {
        guard !isShieldQuoteResolved, let shieldQuoteOperation else {
            return
        }

        interactor.estimateShieldQuote(for: shieldQuoteOperation)
    }
}
