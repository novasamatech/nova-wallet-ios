import Foundation

extension SwapSetupPresenter {
    func scheduleMaxFeeEstimate() {
        maxFeeEstimateDebouncer.debounce { [weak self] in
            self?.estimateMaxFeeIfNeeded()
        }
    }

    func scheduleMaxFeeEstimateIfNeeded() {
        guard
            isPayAmountEmpty,
            getQuoteArgs() == nil,
            isFeeAssetSettled,
            !maxFeeEstimation.isSpent,
            getMaxFeeEstimationPair() != nil else {
            return
        }

        scheduleMaxFeeEstimate()
    }

    func restartMaxFeeEstimate() {
        maxFeeEstimateDebouncer.cancel()
        maxFeeEstimation.reset()
        interactor.cancelMaxFeeEstimate()

        scheduleMaxFeeEstimate()
    }

    func cancelMaxFeeEstimate() {
        maxFeeEstimateDebouncer.cancel()
        maxFeeEstimation.cancel()
        interactor.cancelMaxFeeEstimate()
    }

    func cancelMaxFeeEstimate(onEntering amount: Decimal?) {
        guard let amount, amount > 0 else {
            return
        }

        cancelMaxFeeEstimate()
    }

    var canPayFeeInPayAsset: Bool? {
        guard let payAssetFeeSupport, payAssetFeeSupport.chainAssetId == getPayChainAsset()?.chainAssetId else {
            return nil
        }

        return payAssetFeeSupport.canPayFee
    }

    func getMaxFeeEstimate() -> AssetExchangeFee? {
        getMaxFeeEstimationPair().flatMap { maxFeeEstimation.fee(for: $0) }
    }

    func didReceive(maxFeeEstimate fee: AssetExchangeFee, for quoteArgs: AssetConversion.QuoteArgs) {
        guard isPayAmountEmpty, maxFeeEstimation.complete(with: fee, for: quoteArgs) else {
            return
        }

        providePayTitle()
    }
}

// MARK: Private

private extension SwapSetupPresenter {
    var isPayAmountEmpty: Bool {
        switch payAmountInput {
        case .none:
            true
        case let .absolute(value):
            value <= 0
        case .rate:
            false
        }
    }

    func getMaxFeeEstimationPair() -> SwapMaxFeeEstimation.Pair? {
        guard
            let payChainAsset = getPayChainAsset(),
            let receiveChainAsset = getReceiveChainAsset(),
            let feeChainAsset = getFeeChainAsset() else {
            return nil
        }

        return SwapMaxFeeEstimation.Pair(
            assetIn: payChainAsset.chainAssetId,
            assetOut: receiveChainAsset.chainAssetId,
            feeAssetId: feeChainAsset.chainAssetId
        )
    }

    var isFeeAssetSettled: Bool {
        canPayFeeInPayAsset != nil && utilityAssetBalance != nil && utilityAssetBalanceExistense != nil
    }

    func estimateMaxFeeIfNeeded() {
        guard isPayAmountEmpty, getQuoteArgs() == nil, isFeeAssetSettled else {
            return
        }

        switchFeeChainAssetIfNecessary()
        let amount = getMaxModel(feeModel: nil).calculateInPlank()

        guard
            let pair = getMaxFeeEstimationPair(),
            let feeChainAsset = getFeeChainAsset(),
            amount > 0 else {
            return
        }

        let quoteArgs = AssetConversion.QuoteArgs(
            assetIn: pair.assetIn,
            assetOut: pair.assetOut,
            amount: amount,
            direction: .sell
        )

        guard maxFeeEstimation.start(for: pair, quoteArgs: quoteArgs) else {
            return
        }

        interactor.estimateMaxFee(for: quoteArgs, slippage: slippage, feeAsset: feeChainAsset)
    }
}
