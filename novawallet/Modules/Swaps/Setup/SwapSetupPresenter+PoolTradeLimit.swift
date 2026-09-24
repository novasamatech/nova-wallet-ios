import Foundation

extension SwapSetupPresenter {
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
