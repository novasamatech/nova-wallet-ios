import Foundation

extension SubtensorConfirmPresenter: SubtensorShieldQuoteHandling {
    var transferable: Balance? { isBalanceLoaded ? (balance?.transferable ?? 0) : nil }
    var isRoot: Bool { model.target.isRoot }
    var shieldWalletType: MetaAccountModelType { model.account.chainAccount.type }
    var shieldInteractor: SubtensorBaseInteractorInputProtocol { interactor }
    var activeShieldQuote: SubtensorShieldQuote? { isShieldOn ? eligibleShieldQuote : nil }
    var waitsForShieldQuote: Bool { isShieldable && isShieldOn && !isShieldUnavailable }

    var isShieldQuotePending: Bool {
        let isDepositPending = existentialDeposit == nil && !isExistentialDepositFailed

        return !isShieldQuoteResolved || (shieldQuote != nil && (transferable == nil || isDepositPending))
    }

    func applyShieldQuoteChange() {
        provideViewModel()
    }
}

extension SubtensorConfirmPresenter {
    var isShieldUnavailable: Bool {
        isShieldable && !isShieldQuotePending && eligibleShieldQuote == nil
    }

    func provideShieldState() {
        guard isShieldable else {
            view?.didReceiveShield(viewModel: nil)
            return
        }

        if isShieldUnavailable {
            view?.didReceiveShield(viewModel: .unavailable)
        } else if isShieldOn, isShieldQuotePending {
            view?.didReceiveShield(viewModel: .loading)
        } else {
            view?.didReceiveShield(viewModel: .available(isOn: isShieldOn))
        }
    }

    func toggleShield() {
        isShieldOn.toggle()

        provideViewModel()
    }

    func refreshFee() {
        refreshFee(requotingShield: true)
    }

    func refreshFeeAtTap() {
        refreshFee(requotingShield: !isShieldUnavailable)
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
        refreshFeeAtTap()
    }
}

private extension SubtensorConfirmPresenter {
    func refreshFee(requotingShield: Bool) {
        let acknowledged = quoteState?.acknowledged

        guard let operation = createOperation(limitPrice: acknowledged?.limitPrice, quote: acknowledged) else {
            refreshQuote()
            return
        }

        interactor.estimateFee(for: operation)

        if requotingShield {
            requestFreshShieldQuote(for: operation)
        }
    }
}
