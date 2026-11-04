import Foundation

extension SwapModel {
    struct InsufficientDueCollateral {
        let available: Decimal
    }

    func checkEnoughCollateralToSpend() -> InsufficientBalanceReason? {
        guard case let .limited(limit) = payAssetCollateralLimit else {
            return nil
        }

        let fee = feeModel?.totalFeeInAssetIn(payChainAsset) ?? 0
        let swapAmount = spendingAmountInPlank ?? 0

        guard swapAmount + fee > limit else {
            return nil
        }

        let model = InsufficientDueCollateral(
            available: limit.subtractOrZero(fee).decimal(assetInfo: payChainAsset.assetDisplayInfo)
        )

        return .collateralInUse(model)
    }
}
