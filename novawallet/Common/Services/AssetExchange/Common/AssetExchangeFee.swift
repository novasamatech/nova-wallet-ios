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
    func originPostsubmissionFeeInAsset(
        _ asset: ChainAsset,
        matchingPayer: AssetExchangeFeePayerMatcher = .selectedAccount
    ) -> Balance {
        guard let originFee = operationFees.first else {
            return 0
        }

        return originFee.postSubmissionFee.totalAmountIn(
            asset: asset.chainAssetId,
            matchingPayer: matchingPayer
        )
    }

    func originFeeInAsset(
        _ asset: ChainAsset,
        matchingPayer: AssetExchangeFeePayerMatcher = .selectedAccount
    ) -> Balance {
        guard let originFee = operationFees.first else {
            return 0
        }

        return originFee.totalAmountIn(asset: asset.chainAssetId, matchingPayer: matchingPayer)
    }

    func originExtrinsicFee() -> ExtrinsicFeeProtocol? {
        operationFees.first?.submissionFee
    }

    func postSubmissionFeeInAssetIn(
        _ assetIn: ChainAsset,
        matchingPayer: AssetExchangeFeePayerMatcher = .selectedAccount
    ) -> Balance {
        guard let originFee = operationFees.first else {
            return 0
        }

        let originFeeAmount = originFee.postSubmissionFee.totalAmountIn(
            asset: assetIn.chainAssetId,
            matchingPayer: matchingPayer
        )

        return originFeeAmount + intermediateFeesInAssetIn
    }

    func totalFeeInAssetIn(
        _ assetIn: ChainAsset,
        matchingPayer: AssetExchangeFeePayerMatcher = .selectedAccount
    ) -> Balance {
        guard let originFee = operationFees.first else {
            return 0
        }

        let originFeeAmount = originFee.totalAmountIn(
            asset: assetIn.chainAssetId,
            matchingPayer: matchingPayer
        )

        return originFeeAmount + intermediateFeesInAssetIn
    }

    var hasOriginPostSubmissionByAccount: Bool {
        guard let originFee = operationFees.first else {
            return false
        }

        return !originFee.postSubmissionFee.paidByAccount.isEmpty
    }

    func calculateTotalFeeInFiat(
        matching operations: [AssetExchangeMetaOperationProtocol],
        priceStore: AssetExchangePriceStoring
    ) -> Decimal {
        zip(operations, operationFees).map { operation, fee in
            fee.totalInFiat(in: operation.assetIn.chain, priceStore: priceStore)
        }.reduce(Decimal(0)) { $0 + $1 }
    }
}
