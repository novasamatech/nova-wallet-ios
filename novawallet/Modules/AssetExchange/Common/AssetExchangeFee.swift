import Foundation

struct AssetExchangeFeeArgs {
    let route: AssetExchangeRoute
    let slippage: BigRational
    let feeAssetId: ChainAssetId?
}

struct AssetExchangeFee: Equatable {
    let route: AssetExchangeRoute
    let fees: [AssetExchangeOperationFee]
    let slippage: BigRational
    let feeAssetId: ChainAssetId?

    // TODO: Get rid of temp vars
    var networkFee: AssetConversion.AmountWithNative {
        let amount = fees.first?.submissionFee.amount.amount ?? 0

        return .init(targetAmount: amount, nativeAmount: amount)
    }

    var networkNativeFeeAddition: AssetConversion.AmountWithNative {
        let amount = fees.first?.postSubmissionFee.paidByAccount.first?.amount.amount ?? 0

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
