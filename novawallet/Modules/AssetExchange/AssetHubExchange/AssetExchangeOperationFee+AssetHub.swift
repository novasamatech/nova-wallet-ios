import Foundation

extension AssetExchangeOperationFee {
    init(extrinsicFee: ExtrinsicFeeProtocol, args: AssetExchangeAtomicOperationArgs) {
        submissionFee = .init(
            amountWithAsset: .init(
                amount: extrinsicFee.amount,
                asset: args.feeAsset
            ),
            payer: extrinsicFee.payer
        )

        postSubmissionFee = .init(paidByAccount: [], paidFromAmount: [])
    }
}
