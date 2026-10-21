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

    var activeShieldQuote: SubtensorShieldQuote? {
        isShieldOn ? eligibleShieldQuote : nil
    }

    var networkFee: ExtrinsicFeeProtocol? {
        guard isShieldQuoteResolved else {
            return nil
        }

        return activeShieldQuote?.totalFee ?? fee
    }

    func provideShieldState() {
        view?.didReceiveShield(isOn: eligibleShieldQuote != nil ? isShieldOn : nil)
    }

    func toggleShield() {
        isShieldOn.toggle()

        provideViewModel()
    }

    func retryUnresolvedShieldQuote() {
        guard !isShieldQuoteResolved, let shieldQuoteOperation else {
            return
        }

        interactor.estimateShieldQuote(for: shieldQuoteOperation)
    }
}
