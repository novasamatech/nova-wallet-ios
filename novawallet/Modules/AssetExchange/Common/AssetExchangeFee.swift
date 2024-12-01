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
}

extension AssetExchangeFee {
    func originPostsubmissionFeeIn(assetIn: ChainAsset) -> Balance {
        guard let originFee = operationFees.first else {
            return 0
        }

        return originFee.postSubmissionFee.totalAmountIn(asset: assetIn.chainAssetId)
    }

    func originFeeIn(assetIn: ChainAsset) -> Balance {
        guard let originFee = operationFees.first else {
            return 0
        }

        return originFee.totalAmountIn(asset: assetIn.chainAssetId)
    }

    func postSubmissionFeeInAssetIn(_ assetIn: ChainAsset) -> Balance {
        guard let originFee = operationFees.first else {
            return 0
        }

        return originFee.postSubmissionFee.totalAmountIn(asset: assetIn.chainAssetId) + intermediateFeesInAssetIn
    }

    func totalFeeInAssetIn(_ assetIn: ChainAsset) -> Balance {
        guard let originFee = operationFees.first else {
            return 0
        }

        return originFee.totalAmountIn(asset: assetIn.chainAssetId) + intermediateFeesInAssetIn
    }

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
