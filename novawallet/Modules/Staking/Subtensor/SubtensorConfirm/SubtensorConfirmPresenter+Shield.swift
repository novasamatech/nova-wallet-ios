import Foundation

extension SubtensorConfirmPresenter {
    var eligibleShieldQuote: SubtensorShieldQuote? {
        let input = SubtensorShieldEligibilityInput(
            walletType: model.account.chainAccount.type,
            quote: shieldQuote,
            transferable: balance?.transferable,
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
}
