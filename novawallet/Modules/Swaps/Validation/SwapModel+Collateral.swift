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
        let collateralCeiling = limit.subtractOrZero(fee)

        guard
            collateralCeiling < (payAssetBalance?.transferable ?? 0).subtractOrZero(fee),
            (spendingAmountInPlank ?? 0) + fee > limit else {
            return nil
        }

        let model = InsufficientDueCollateral(
            available: collateralCeiling.decimal(assetInfo: payChainAsset.assetDisplayInfo)
        )

        return .collateralInUse(model)
    }
}
