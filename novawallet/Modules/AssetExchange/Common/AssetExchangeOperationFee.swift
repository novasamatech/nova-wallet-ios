import Foundation
import BigInt

enum AssetExchangeOperationFeeError: Error {
    case assetMismatch
    case payerMismatch
}

struct AssetExchangeOperationFee: Equatable {
    struct Amount: Equatable {
        let amount: Balance
        let asset: ChainAssetId

        func totalAmountEnsuring(asset: ChainAssetId) throws -> Balance {
            guard self.asset == asset else {
                throw AssetExchangeOperationFeeError.assetMismatch
            }

            return amount
        }

        func totalAmountIn(asset: ChainAssetId) -> Balance {
            self.asset == asset ? amount : 0
        }
    }

    struct Submission: Equatable {
        let amountWithAsset: Amount

        // nil means selected account pays fee
        let payer: ExtrinsicFeePayer?

        let weight: BigUInt

        func totalAmountEnsuring(
            asset: ChainAssetId,
            matchingPayer: AssetExchangeFeePayerMatcher
        ) throws -> Balance {
            guard matchingPayer.matches(payer: payer) else {
                throw AssetExchangeOperationFeeError.payerMismatch
            }

            return try amountWithAsset.totalAmountEnsuring(asset: asset)
        }

        func totalAmountIn(
            asset: ChainAssetId,
            matchingPayer: AssetExchangeFeePayerMatcher
        ) -> Balance {
            guard matchingPayer.matches(payer: payer) else {
                return 0
            }

            return amountWithAsset.totalAmountIn(asset: asset)
        }
    }

    struct AmountByPayer: Equatable {
        let amountWithAsset: Amount

        let payer: ExtrinsicFeePayer?

        func totalAmountEnsuring(
            asset: ChainAssetId,
            matchingPayer: AssetExchangeFeePayerMatcher
        ) throws -> Balance {
            guard matchingPayer.matches(payer: payer) else {
                throw AssetExchangeOperationFeeError.payerMismatch
            }

            return try amountWithAsset.totalAmountEnsuring(asset: asset)
        }

        func totalAmountIn(
            asset: ChainAssetId,
            matchingPayer: AssetExchangeFeePayerMatcher
        ) -> Balance {
            guard matchingPayer.matches(payer: payer) else {
                return 0
            }

            return amountWithAsset.totalAmountIn(asset: asset)
        }
    }

    struct PostSubmission: Equatable {
        /**
         * Post-submission fees paid by (some) origin account.
         * This is typed as `AmountByAccount` as those fee might still
         * use different accounts (e.g. delivery fees are always paid from requested account)
         */
        let paidByAccount: [AmountByPayer]

        /**
         * Post-submission fees paid from swapping amount directly. Its payment is isolated
         * and does not involve any withdrawals from accounts
         */
        let paidFromAmount: [Amount]

        func totalByAccountEnsuring(
            asset: ChainAssetId,
            matchingPayer: AssetExchangeFeePayerMatcher
        ) throws -> Balance {
            try paidByAccount.reduce(0) { total, item in
                let current = try item.totalAmountEnsuring(
                    asset: asset,
                    matchingPayer: matchingPayer
                )

                return total + current
            }
        }

        func totalByAccountAmountIn(
            asset: ChainAssetId,
            matchingPayer: AssetExchangeFeePayerMatcher
        ) -> Balance {
            paidByAccount.reduce(0) { total, item in
                total + item.totalAmountIn(asset: asset, matchingPayer: matchingPayer)
            }
        }

        func totalFromAmountEnsuring(asset: ChainAssetId) throws -> Balance {
            try paidFromAmount.reduce(0) { total, item in
                let current = try item.totalAmountEnsuring(asset: asset)

                return total + current
            }
        }

        func totalFromAmountIn(asset: ChainAssetId) -> Balance {
            paidFromAmount.reduce(0) { total, item in
                total + item.totalAmountIn(asset: asset)
            }
        }

        func totalAmountEnsuring(
            asset: ChainAssetId,
            matchingPayer: AssetExchangeFeePayerMatcher
        ) throws -> Balance {
            let totalByAccount = try totalByAccountEnsuring(
                asset: asset,
                matchingPayer: matchingPayer
            )

            let totalFromAmount = try totalFromAmountEnsuring(asset: asset)

            return totalByAccount + totalFromAmount
        }

        func totalAmountIn(
            asset: ChainAssetId,
            matchingPayer: AssetExchangeFeePayerMatcher
        ) -> Balance {
            let totalByAccount = totalByAccountAmountIn(
                asset: asset,
                matchingPayer: matchingPayer
            )

            let totalFromAmount = totalFromAmountIn(asset: asset)

            return totalByAccount + totalFromAmount
        }
    }

    /**
     *  Fee that is paid when submitting transaction
     */
    let submissionFee: Submission

    /**
     *  Fee that is paid after transaction started execution on-chain. For example, delivery fee for the crosschain
     */
    let postSubmissionFee: PostSubmission
}

extension AssetExchangeOperationFee {
    func totalAmountToPayFromSelectedAccount() throws -> Balance {
        let asset = submissionFee.amountWithAsset.asset

        let submissionByAccount = try submissionFee.totalAmountEnsuring(
            asset: asset,
            matchingPayer: .selectedAccount
        )

        let postSubmissionByAccount = try postSubmissionFee.totalByAccountEnsuring(
            asset: submissionFee.amountWithAsset.asset,
            matchingPayer: .selectedAccount
        )

        return submissionByAccount + postSubmissionByAccount
    }

    func totalToPayFromAmountEnsuring(asset: ChainAssetId) throws -> Balance {
        try postSubmissionFee.totalFromAmountEnsuring(asset: asset)
    }

    func totalEnsuringSubmissionAsset(payerMatcher: AssetExchangeFeePayerMatcher) throws -> Balance {
        let asset = submissionFee.amountWithAsset.asset

        let submissionTotal = try submissionFee.totalAmountEnsuring(
            asset: asset,
            matchingPayer: payerMatcher
        )

        let postSubmissionTotal = try postSubmissionFee.totalAmountEnsuring(
            asset: asset,
            matchingPayer: payerMatcher
        )

        return submissionTotal + postSubmissionTotal
    }

    func totalAmountIn(
        asset: ChainAssetId,
        matchingPayer: AssetExchangeFeePayerMatcher
    ) -> Balance {
        let submissionTotal = submissionFee.totalAmountIn(
            asset: asset,
            matchingPayer: matchingPayer
        )

        let postSubmissionTotal = postSubmissionFee.totalAmountIn(
            asset: asset,
            matchingPayer: matchingPayer
        )

        return submissionTotal + postSubmissionTotal
    }
}

extension AssetExchangeOperationFee.Submission: ExtrinsicFeeProtocol {
    var amount: Balance { amountWithAsset.amount }
}
