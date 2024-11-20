import Foundation

struct AssetExchangeFeeArgs {
    let route: AssetExchangeRoute
    let slippage: BigRational
    let feeAssetId: ChainAssetId
}

enum AssetExchangeFeeError: Error {
    case mismatchBetweenFeeAndRoute
}

struct AssetExchangeFee: Equatable {
    let route: AssetExchangeRoute
    let operationFees: [AssetExchangeOperationFee]
    let intermediateFeesInAssetIn: Balance
    let slippage: BigRational
    let feeAssetId: ChainAssetId

    // TODO: Get rid of temp vars
    var networkFee: AssetConversion.AmountWithNative {
        let amount = operationFees.first?.submissionFee.amountWithAsset.amount ?? 0

        return .init(targetAmount: amount, nativeAmount: amount)
    }

    var networkNativeFeeAddition: AssetConversion.AmountWithNative {
        let amount = operationFees.first?.postSubmissionFee.paidByAccount.first?.amountWithAsset.amount ?? 0

        return .init(
            targetAmount: amount,
            nativeAmount: amount
        )
    }

    var totalFee: AssetConversion.AmountWithNative {
        let targetAmount = networkFee.targetAmount + networkNativeFeeAddition.targetAmount
        let networkAmount = networkFee.nativeAmount + networkNativeFeeAddition.nativeAmount

        return .init(targetAmount: targetAmount, nativeAmount: networkAmount)
    }
}

extension AssetExchangeFee {
    func calculateTotalFeeInFiat(
        assetIn: ChainAsset,
        assetInPrice: PriceData?,
        feeAsset: ChainAsset,
        feeAssetPrice: PriceData?
    ) -> Decimal {
        guard let originFee = operationFees.first else {
            return 0
        }

        let originFeeInAssetIn = originFee.totalAmountIn(asset: assetIn.chainAssetId)

        let totalFeeInAssetIn = originFeeInAssetIn + intermediateFeesInAssetIn

        let totalAmountInFeeInFiat = Decimal.fiatValue(
            from: totalFeeInAssetIn,
            price: assetInPrice,
            precision: assetIn.assetDisplayInfo.assetPrecision
        )

        guard feeAsset.chainAssetId != assetIn.chainAssetId else {
            return totalAmountInFeeInFiat
        }

        let totalFeeInFeeAsset = originFee.totalAmountIn(asset: feeAsset.chainAssetId)
        let totalFeeAssetFeeInFiat = Decimal.fiatValue(
            from: totalFeeInFeeAsset,
            price: feeAssetPrice,
            precision: feeAsset.assetDisplayInfo.assetPrecision
        )

        return totalAmountInFeeInFiat + totalFeeAssetFeeInFiat
    }
}
