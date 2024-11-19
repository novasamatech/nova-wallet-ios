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
