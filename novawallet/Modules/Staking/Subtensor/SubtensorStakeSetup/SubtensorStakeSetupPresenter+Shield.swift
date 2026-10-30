import Foundation

extension SubtensorStakeSetupPresenter: SubtensorShieldQuoteHandling {
    var shieldWalletType: MetaAccountModelType { selectedAccount.chainAccount.type }
    var shieldInteractor: SubtensorBaseInteractorInputProtocol { interactor }

    func applyShieldQuoteChange() {
        applyMaxChange()
    }

    func applyShieldQuoteFallback() {
        maxRefreshTransferable = transferable
        applyMaxChange()
    }
}

extension SubtensorStakeSetupPresenter {
    var maxAmount: Balance? {
        guard let transferable, let networkFee else {
            return nil
        }

        return SubtensorAmountPolicy.maxBuyOrStake(
            transferable: transferable,
            networkFee: networkFee.amountForCurrentAccount ?? 0
        )
    }

    // Max depends on the quote and the quote on the amount: one re-request per transferable
    // between fee requests, so a quote that moves Max again settles instead of ping-ponging
    func refreshFeeForNewMax() {
        guard
            maxAmount != nil,
            transferable != maxRefreshTransferable,
            inputAmountOrPlaceholder() != requestedFeeAmount else {
            return
        }

        refreshFee()
        maxRefreshTransferable = transferable
    }
}

private extension SubtensorStakeSetupPresenter {
    var requestedFeeAmount: Balance? {
        switch shieldQuoteOperation {
        case let .rootStake(_, amount), let .subnetBuy(_, _, amount, _, _):
            amount
        case .rootUnstake, .rootUnstakeGroup, .subnetSell, .subnetSellGroup, .rootClaim, nil:
            nil
        }
    }
}
