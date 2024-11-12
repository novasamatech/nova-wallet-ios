import Foundation

extension AssetExchangeOperationFee {
    init(
        crosschainFee: XcmFeeModelProtocol,
        originFee: ExtrinsicFeeProtocol,
        assetIn: ChainAssetId,
        assetOut _: ChainAssetId,
        args: AssetExchangeAtomicOperationArgs
    ) {
        submissionFee = .init(
            amountWithAsset: .init(
                amount: originFee.amount,
                asset: args.feeAsset
            ),
            payer: originFee.payer
        )

        let paidByAccount: [AmountByPayer] = if crosschainFee.senderPart > 0 {
            [
                .init(
                    amountWithAsset: .init(amount: crosschainFee.senderPart, asset: nil),
                    payer: nil
                )
            ]
        } else {
            []
        }

        let feeAsset = assetIn.assetId == AssetModel.utilityAssetId ? nil : assetIn
        let paidFromAmount: [Amount] = if crosschainFee.holdingPart > 0 {
            [
                .init(amount: crosschainFee.holdingPart, asset: feeAsset)
            ]
        } else {
            []
        }

        postSubmissionFee = .init(
            paidByAccount: paidByAccount,
            paidFromAmount: paidFromAmount
        )
    }
}
