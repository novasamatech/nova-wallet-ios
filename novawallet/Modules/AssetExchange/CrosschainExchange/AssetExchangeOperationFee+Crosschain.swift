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
            amount: .init(
                amount: originFee.amount,
                asset: args.feeAsset
            ),
            payer: originFee.payer
        )

        postSubmissionFee = .init(
            paidByAccount: [
                .init(
                    amount: .init(amount: crosschainFee.senderPart, asset: nil),
                    payer: nil
                )
            ],
            paidFromAmount: [
                .init(amount: crosschainFee.senderPart, asset: assetIn)
            ]
        )
    }
}
