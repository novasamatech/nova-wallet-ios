import Foundation

struct AssetExchangeOperationFee {
    struct Amount {
        let amount: Balance

        // TODO: nil means native, probably make it explicit
        let asset: ChainAssetId?
    }

    struct AmountByPayer {
        let amount: Amount

        // TODO: nil means account from the current wallet, probably make it explicit and rename to general type
        let payer: ExtrinsicFeePayer?
    }

    struct PostSubmission {
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
