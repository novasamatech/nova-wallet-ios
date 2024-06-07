import Foundation

extension FeeIndexedExtrinsicResult {
    func convertToTotalFee() -> FeeExtrinsicResult {
        do {
            let totalFee = try results.map(\.result).reduce(ExtrinsicFee.zero()) { accum, result in
                let newFeeInfo = try result.get()
                return ExtrinsicFee(
                    amount: newFeeInfo.amount + accum.amount,
                    payer: newFeeInfo.payer,
                    weight: newFeeInfo.weight + accum.weight
                )
            }

            return .success(totalFee)
        } catch {
            return .failure(error)
        }
    }
}
