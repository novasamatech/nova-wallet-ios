import Foundation

enum AssetExchangeOperationFeeError: Error {
    case assetMismatch
}

struct AssetExchangeOperationFee: Equatable {
    struct Amount: Equatable {
        let amount: Balance

        // TODO: nil means native, probably make it explicit
        let asset: ChainAssetId?

        func totalAmountEnsuring(asset: ChainAssetId?) throws -> Balance {
            guard self.asset == asset else {
                throw AssetExchangeOperationFeeError.assetMismatch
            }

            return amount
        }
    }

    struct AmountByPayer: Equatable {
        let amountWithAsset: Amount

        // TODO: nil means account from the current wallet, probably make it explicit and rename to general type
        let payer: ExtrinsicFeePayer?

        func totalAmountEnsuring(asset: ChainAssetId?) throws -> Balance {
            try amountWithAsset.totalAmountEnsuring(asset: asset)
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

        func totalByAccountEnsuring(asset: ChainAssetId?) throws -> Balance {
            try paidByAccount.reduce(0) { total, item in
                let current = try item.totalAmountEnsuring(asset: asset)

                return total + current
            }
        }

        func totalFromAmountEnsuring(asset: ChainAssetId?) throws -> Balance {
            try paidFromAmount.reduce(0) { total, item in
                let current = try item.totalAmountEnsuring(asset: asset)

                return total + current
            }
        }

        func totalAmountEnsuring(asset: ChainAssetId?) throws -> Balance {
            let totalByAccount = try totalByAccountEnsuring(asset: asset)

            let totalFromAmount = try totalFromAmountEnsuring(asset: asset)

            return totalByAccount + totalFromAmount
        }
    }

    /**
     *  Fee that is paid when submitting transaction
     */
    let submissionFee: AmountByPayer

    /**
     *  Fee that is paid after transaction started execution on-chain. For example, delivery fee for the crosschain
     */
    let postSubmissionFee: PostSubmission
}

extension AssetExchangeOperationFee {
    func totalAmountToPayFromAccount() throws -> Balance {
        let postSubmissionByAccount = try postSubmissionFee.totalByAccountEnsuring(
            asset: submissionFee.amountWithAsset.asset
        )

        return submissionFee.amountWithAsset.amount + postSubmissionByAccount
    }

    func totalToPayFromAmountEnsuring(asset: ChainAssetId?) throws -> Balance {
        try postSubmissionFee.totalFromAmountEnsuring(asset: asset)
    }

    func totalEnsuringSubmissionAsset() throws -> Balance {
        let postSubmissionTotal = try postSubmissionFee.totalAmountEnsuring(asset: submissionFee.amountWithAsset.asset)

        return submissionFee.amountWithAsset.amount + postSubmissionTotal
    }
}