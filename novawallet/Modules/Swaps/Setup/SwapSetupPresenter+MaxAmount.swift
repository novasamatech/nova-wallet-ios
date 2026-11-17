import Foundation

extension SwapSetupPresenter {
    func getMaxAmountFee() -> AssetExchangeFee? {
        let currentPairFee = getCurrentPairFee()

        guard
            payAmountInput?.isMax == true,
            let payChainAsset = getPayChainAsset(),
            let quoteArgsMaxAmountFee,
            isQuotedForCurrentPair(quoteArgsMaxAmountFee) else {
            return getMaxFeeEstimate() ?? currentPairFee
        }

        guard let currentPairFee else {
            return quoteArgsMaxAmountFee
        }

        guard quote?.hasSamePath(other: quoteArgsMaxAmountFee.route) == true else {
            return currentPairFee
        }

        let isWithinMargin = SwapMaxModel.isFee(
            currentPairFee.totalFeeInAssetIn(payChainAsset),
            withinMarginOf: quoteArgsMaxAmountFee.totalFeeInAssetIn(payChainAsset)
        )

        return isWithinMargin ? quoteArgsMaxAmountFee : currentPairFee
    }

    func discardFeeOfAnotherPair() -> Bool {
        guard let fee, !isQuotedForCurrentPair(fee) else {
            return false
        }

        self.fee = nil

        return true
    }
}

private extension SwapSetupPresenter {
    func isQuotedForCurrentPair(_ maxAmountFee: AssetExchangeFee) -> Bool {
        maxAmountFee.feeAssetId == getFeeChainAsset()?.chainAssetId &&
            maxAmountFee.route.items.first?.edge.origin == getPayChainAsset()?.chainAssetId &&
            maxAmountFee.route.items.last?.edge.destination == getReceiveChainAsset()?.chainAssetId
    }

    func getCurrentPairFee() -> AssetExchangeFee? {
        fee.flatMap { isQuotedForCurrentPair($0) ? $0 : nil }
    }
}
