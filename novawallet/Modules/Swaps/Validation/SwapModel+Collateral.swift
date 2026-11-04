import Foundation

extension SwapModel {
    struct InsufficientDueCollateral {
        let available: Decimal
    }

    func checkEnoughCollateralToSpend() -> InsufficientBalanceReason? {
        let fee = feeModel?.totalFeeInAssetIn(payChainAsset) ?? 0

        guard
            case let .limited(limit) = payAssetCollateralLimit,
            let collateralCeiling = payAssetCollateralLimit?.ceiling(afterFee: fee),
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
