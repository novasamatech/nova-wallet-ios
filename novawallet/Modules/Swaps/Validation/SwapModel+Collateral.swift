import Foundation

extension SwapModel {
    struct InsufficientDueCollateral {
        let available: Decimal
    }

    func checkEnoughCollateralToSpend() -> InsufficientBalanceReason? {
        guard case let .limited(limit) = payAssetCollateralLimit else {
            return nil
        }

        let balance = payAssetBalance?.transferable ?? 0
        let fee = feeModel?.totalFeeInAssetIn(payChainAsset) ?? 0
        let swapAmount = spendingAmountInPlank ?? 0

        let collateralCeiling = limit.subtractOrZero(fee)
        let balanceCeiling = balance.subtractOrZero(fee)

        guard collateralCeiling < balanceCeiling, swapAmount + fee > limit else {
            return nil
        }

        let model = InsufficientDueCollateral(
            available: collateralCeiling.decimal(assetInfo: payChainAsset.assetDisplayInfo)
        )

        return .collateralInUse(model)
    }
}
