import Foundation

extension SwapSetupPresenter {
    func isMaxCorrectionConverged(for direction: AssetConversion.Direction) -> Bool {
        guard
            direction == .sell,
            let payChainAsset = getPayChainAsset(),
            let payInPlank = getPayAmount(for: payAmountInput)?.toSubstrateAmount(
                precision: Int16(payChainAsset.assetDisplayInfo.assetPrecision)
            ) else {
            return false
        }

        return payInPlank == getQuoteArgs()?.amount
    }

    var isQuietMaxRequote: Bool {
        guard
            let quietQuoteArgs = maxBalanceRequote.quietQuoteArgs,
            quietQuoteArgs == getQuoteArgs(),
            let quote,
            let fee else {
            return false
        }

        return quote.hasSamePath(other: fee.route)
    }

    func requoteMaxOnBalanceChange() {
        guard payAmountInput?.isMax == true else {
            return
        }

        guard !maxBalanceRequote.isAwaitingPayBalance else {
            requoteMaxOnLoadedPayBalance()
            return
        }

        guard quote != nil else {
            return
        }

        if isFeePending {
            requoteQuietMaxIfUnaffordable()
        } else {
            requoteMaxForBalanceIfNeeded()
        }
    }

    func requoteMaxOnNewFee() {
        maxBalanceRequote.quietQuoteArgs = nil

        if isMaxFeeAnchored {
            requoteMaxForBalanceIfNeeded()
        } else {
            requoteMaxIfNotConverged()
        }
    }

    func awaitPayBalanceIfNeeded(for payChainAsset: ChainAsset) {
        guard payAmountInput?.isMax == true, payAssetBalance == nil else {
            stopAwaitingPayBalance()
            return
        }

        guard maxBalanceRequote.awaitedPayAssetId != payChainAsset.chainAssetId else {
            return
        }

        maxBalanceRequote.awaitedPayAssetId = payChainAsset.chainAssetId

        payBalanceWaitDebouncer.debounce { [weak self] in
            self?.fallBackOnPayBalanceTimeout()
        }
    }

    func stopAwaitingPayBalance() {
        guard maxBalanceRequote.isAwaitingPayBalance else {
            return
        }

        maxBalanceRequote.awaitedPayAssetId = nil
        payBalanceWaitDebouncer.cancel()
        provideQuoteState()
    }

    func catchUpMaxBalanceRequote() {
        guard maxBalanceRequote.isCatchUpPending else {
            return
        }

        maxBalanceRequote.isCatchUpPending = false

        guard
            payAmountInput?.isMax == true,
            quote != nil,
            !isFeePending,
            let quoteArgs = getQuoteArgs(),
            quoteArgs.direction == .sell,
            !isMaxCorrectionConverged(for: .sell) else {
            return
        }

        if isAffordableByMax(quoteArgs) {
            requoteMaxQuietly()
        } else {
            requoteUnaffordableMax()
        }
    }
}

extension SwapSetupPresenter: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        requoteMaxOnBalanceChange()
    }
}

// MARK: Private

private extension SwapSetupPresenter {
    var isMaxFeeAnchored: Bool {
        guard let quoteArgsMaxAmountFee else {
            return false
        }

        return getMaxAmountFee() == quoteArgsMaxAmountFee
    }

    func isAffordableByMax(_ quoteArgs: AssetConversion.QuoteArgs) -> Bool {
        guard
            let payChainAsset = getPayChainAsset(),
            let maxInPlank = getMaxModel().calculate().toSubstrateAmount(
                precision: payChainAsset.assetDisplayInfo.assetPrecision
            ) else {
            return false
        }

        return quoteArgs.amount <= maxInPlank
    }

    func requoteMaxForBalanceIfNeeded() {
        guard
            let quoteArgs = getQuoteArgs(),
            quoteArgs.direction == .sell,
            !isMaxCorrectionConverged(for: .sell) else {
            requoteMaxIfNotConverged()
            return
        }

        guard requireFrontmost() else {
            deferMaxBalanceRequote()
            return
        }

        if isAffordableByMax(quoteArgs) {
            throttleQuietMaxRequote()
        } else {
            requoteUnaffordableMax()
        }
    }

    func deferMaxBalanceRequote() {
        maxBalanceRequoteScheduler.cancel()
        maxBalanceRequote.isCatchUpPending = true
    }

    func requoteUnaffordableMax() {
        maxBalanceRequoteScheduler.cancel()
        maxBalanceRequote.lastRequoteDate = Date()

        requoteMaxIfNotConverged()
    }

    func throttleQuietMaxRequote() {
        guard !maxBalanceRequoteScheduler.isScheduled else {
            return
        }

        let delay = maxBalanceRequote.delayUntilNextRequote()

        if delay > 0 {
            scheduleMaxBalanceRequote(after: delay)
        } else {
            requoteMaxQuietly()
        }
    }

    func scheduleMaxBalanceRequote(after delay: TimeInterval) {
        maxBalanceRequoteScheduler.notifyAfter(delay)
    }

    func fallBackOnPayBalanceTimeout() {
        guard maxBalanceRequote.isAwaitingPayBalance else {
            return
        }

        refreshQuote(direction: .buy)
        armQuoteFailureAlert()
    }

    func requoteMaxOnLoadedPayBalance() {
        guard payAssetBalance != nil else {
            return
        }

        refreshQuote(direction: .sell, forceUpdate: false)
        armQuoteFailureAlert()
    }

    func requoteQuietMaxIfUnaffordable() {
        guard
            let quietQuoteArgs = maxBalanceRequote.quietQuoteArgs,
            quietQuoteArgs == getQuoteArgs(),
            !isAffordableByMax(quietQuoteArgs) else {
            return
        }

        maxBalanceRequote.quietQuoteArgs = nil
        requoteUnaffordableMax()

        provideButtonState()
        provideIssues()
    }
}
