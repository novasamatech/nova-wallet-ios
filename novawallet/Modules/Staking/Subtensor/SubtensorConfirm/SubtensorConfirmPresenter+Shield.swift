import Foundation

extension SubtensorConfirmPresenter: SubtensorShieldQuoteHandling {
    var transferable: Balance? { balance?.transferable }
    var isRoot: Bool { model.target.isRoot }
    var shieldWalletType: MetaAccountModelType { model.account.chainAccount.type }
    var shieldInteractor: SubtensorBaseInteractorInputProtocol { interactor }
    var activeShieldQuote: SubtensorShieldQuote? { isShieldOn ? eligibleShieldQuote : nil }
    var waitsForShieldQuote: Bool { isShieldable && isShieldOn && !isShieldQuoteFallback }

    func applyShieldQuoteChange() {
        provideViewModel()
    }
}

extension SubtensorConfirmPresenter {
    func provideShieldState() {
        if eligibleShieldQuote != nil {
            view?.didReceiveShield(viewModel: .available(isOn: isShieldOn))
        } else if isShieldUnavailable {
            view?.didReceiveShield(viewModel: .unavailable)
        } else {
            view?.didReceiveShield(viewModel: nil)
        }
    }

    func toggleShield() {
        isShieldOn.toggle()

        provideViewModel()
    }

    func requestFreshShieldQuote(for operation: SubtensorOperation) {
        guard !isShieldQuoteFallback else {
            return
        }

        if isShieldable {
            isShieldQuoteResolved = false
        }

        requestShieldQuote(for: operation)
    }

    func keepPriceMoveAcknowledgement() {
        if waitsForShieldQuote {
            analytics.holdPriceMoveAcknowledgement()
        }
    }

    func refreshFeeKeepingAcknowledgement() {
        keepPriceMoveAcknowledgement()
        refreshFee()
    }
}
