import Foundation

struct AssetExchangeFeeArgs {
    let route: AssetExchangeRoute
    let slippage: BigRational
    let feeAssetId: ChainAssetId?
}

enum AssetExchangeFeeError: Error {
    case mismatchBetweenFeeAndRoute
}

struct AssetExchangeFee: Equatable {
    let route: AssetExchangeRoute
    let fees: [AssetExchangeOperationFee]
    let slippage: BigRational
    let feeAssetId: ChainAssetId?

    // TODO: Get rid of temp vars
    var networkFee: AssetConversion.AmountWithNative {
        let amount = fees.first?.submissionFee.amountWithAsset.amount ?? 0

        return .init(targetAmount: amount, nativeAmount: amount)
    }

    var networkNativeFeeAddition: AssetConversion.AmountWithNative {
        let amount = fees.first?.postSubmissionFee.paidByAccount.first?.amountWithAsset.amount ?? 0

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
    func calculateAmountInIncludingIntermediateFees() throws -> Balance {
        guard
            let firstSegment = route.items.first,
            route.items.count == fees.count,
            route.items.allSatisfy({ $0.amountOut(for: route.direction) > 0 }) else {
            throw AssetExchangeFeeError.mismatchBetweenFeeAndRoute
        }

        let totalSegments = route.items.count
        let segmentsWithFee = zip(route.items.suffix(totalSegments - 1), fees.suffix(totalSegments - 1))

        let newAmountOut: Balance? = try segmentsWithFee.reversed().reduce(nil) { newAmountOut, segmentWithFee in
            let segment = segmentWithFee.0
            let fee = segmentWithFee.1

            let curAmountIn = segment.amountIn(for: route.direction)
            let curAmountOut = segment.amountOut(for: route.direction)

            let totalFee = try fee.totalEnsuringSubmissionAsset()

            if let newAmountOut {
                return (newAmountOut * curAmountIn).divideByRoundingUp(curAmountOut) + totalFee
            } else {
                return curAmountIn + totalFee
            }
        }

        let firstSegmentIn = firstSegment.amountIn(for: route.direction)
        let firstSegmentOut = firstSegment.amountIn(for: route.direction)

        if let newAmountOut {
            return (newAmountOut * firstSegmentIn).divideByRoundingUp(firstSegmentOut)
        } else {
            return firstSegmentIn
        }
    }
}
