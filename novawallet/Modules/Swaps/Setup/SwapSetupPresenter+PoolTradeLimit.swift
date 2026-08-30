import Foundation

extension SwapSetupPresenter {
    /// Fills a pool's maximum tradable amount into the side the user typed into, and re-quotes.
    ///
    /// It goes through `updatePayAmount` / `updateReceiveAmount` rather than reimplementing them, and
    /// pairs each with `providePayAssetViews` / `provideReceiveAssetViews` — the same pairing `setup()`
    /// uses for an initial amount. That second call is what re-binds the text field: the update methods
    /// are written for the field's own `editingChanged` delegate, where the text is already on screen,
    /// so on their own they would leave the old number visible while the new one is being quoted.
    /// Keeping both in one method is what makes that mistake unrepresentable.
    func applySuggestedAmount(_ amount: Balance, direction: AssetConversion.Direction) {
        let chainAsset = switch direction {
        case .sell: getPayChainAsset()
        case .buy: getReceiveChainAsset()
        }

        guard
            let chainAsset,
            poolLimitCorrectionCounter.incrementCounterIfPossible()
        else {
            return
        }

        let decimalAmount = amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

        switch direction {
        case .sell:
            updatePayAmount(decimalAmount)
            providePayAssetViews()
            view?.didReceive(focus: .payAsset)
        case .buy:
            updateReceiveAmount(decimalAmount)
            provideReceiveAssetViews()
            view?.didReceive(focus: .receiveAsset)
        }
    }
}
