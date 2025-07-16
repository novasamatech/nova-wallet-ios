import Foundation

extension AssetExchangeFee {
    func getInitialAmountIn() throws -> Balance {
        guard
            let firstSegment = route.items.first,
            let firstFees = operationFees.first else {
            throw AssetExchangeFeeError.mismatchBetweenFeeAndRoute
        }

        let amountIn = firstSegment.amountIn(for: route.direction)
        let amountInWithFee = amountIn + intermediateFeesInAssetIn

        let holdingFee = try firstFees.totalToPayFromAmountEnsuring(asset: firstSegment.edge.origin)
        return amountInWithFee + holdingFee
    }
}
