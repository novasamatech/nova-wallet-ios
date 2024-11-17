import Foundation

struct AssetExchangeFeeArgs {
    let route: AssetExchangeRoute
    let slippage: BigRational
    let feeAssetId: ChainAssetId
}

enum AssetExchangeFeeError: Error {
    case mismatchBetweenFeeAndRoute
}

struct AssetExchangeFee {
    let route: AssetExchangeRoute
    let operations: [AssetExchangeAtomicOperationProtocol]
    let operationFees: [AssetExchangeOperationFee]
    let operationExecutionTimes: [TimeInterval]
    let intermediateFeesInAssetIn: Balance
    let slippage: BigRational
    let feeAssetId: ChainAssetId
    let feeAssetPrice: PriceData?

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

extension AssetExchangeFee: Equatable {
    static func == (lhs: AssetExchangeFee, rhs: AssetExchangeFee) -> Bool {
        lhs.route == rhs.route
            && lhs.operationFees == rhs.operationFees
            && lhs.intermediateFeesInAssetIn == rhs.intermediateFeesInAssetIn
            && lhs.slippage == rhs.slippage
            && lhs.feeAssetId == rhs.feeAssetId
            && lhs.feeAssetPrice == rhs.feeAssetPrice
    }
}
