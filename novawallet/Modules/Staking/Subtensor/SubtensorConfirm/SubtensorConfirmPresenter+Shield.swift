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

    var isShieldable: Bool {
        !model.target.isRoot && SubtensorShieldEligibility.supports(walletType: model.account.chainAccount.type)
    }

    var networkFee: ExtrinsicFeeProtocol? {
        guard isShieldable else {
            return fee
        }

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

    func requestShieldQuote(for operation: SubtensorOperation) {
        shieldQuoteOperation = operation

        if isShieldable {
            isShieldQuoteResolved = false
        }

        interactor.estimateShieldQuote(for: operation)
    }

    func refreshFeeKeepingAcknowledgement() {
        if isShieldable {
            analytics.holdPriceMoveAcknowledgement()
        }

        refreshFee()
    }

    func retryUnresolvedShieldQuote() {
        guard !isShieldQuoteResolved, let shieldQuoteOperation else {
            return
        }

        interactor.estimateShieldQuote(for: shieldQuoteOperation)
    }
}
