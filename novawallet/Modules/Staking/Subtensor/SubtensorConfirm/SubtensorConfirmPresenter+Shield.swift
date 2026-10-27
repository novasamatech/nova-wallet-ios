import Foundation

extension SubtensorConfirmPresenter: SubtensorShieldQuoteHandling {
    var transferable: Balance? { balance?.transferable }
    var isRoot: Bool { model.target.isRoot }
    var shieldWalletType: MetaAccountModelType { model.account.chainAccount.type }
    var shieldInteractor: SubtensorBaseInteractorInputProtocol { interactor }
    var activeShieldQuote: SubtensorShieldQuote? { isShieldOn ? eligibleShieldQuote : nil }
    var waitsForShieldQuote: Bool { isShieldable && isShieldOn }

    func applyShieldQuoteChange() {
        provideViewModel()
    }
}

extension SubtensorConfirmPresenter {
    func provideShieldState() {
        view?.didReceiveShield(isOn: eligibleShieldQuote != nil ? isShieldOn : nil)
    }

    func toggleShield() {
        isShieldOn.toggle()

        provideViewModel()
    }

    func requestFreshShieldQuote(for operation: SubtensorOperation) {
        if isShieldable {
            isShieldQuoteResolved = false
        }

        requestShieldQuote(for: operation)
    }

    func keepPriceMoveAcknowledgement() {
        if isShieldable {
            analytics.holdPriceMoveAcknowledgement()
        }
    }

    func refreshFeeKeepingAcknowledgement() {
        keepPriceMoveAcknowledgement()
        refreshFee()
    }
}
