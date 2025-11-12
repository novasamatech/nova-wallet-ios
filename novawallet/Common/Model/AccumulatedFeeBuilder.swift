import Foundation
import BigInt

struct AccumulatedFeeBuilder {
    private let extrinsicFees: [ExtrinsicFeeProtocol]
    private let multiplier: Int

    init(
        fees: [ExtrinsicFeeProtocol] = [],
        multiplier: Int = 1
    ) {
        extrinsicFees = fees
        self.multiplier = multiplier
    }

    func adding(fee: ExtrinsicFeeProtocol) -> Self {
        AccumulatedFeeBuilder(
            fees: extrinsicFees + [fee],
            multiplier: multiplier
        )
    }

    func multiplied(by multiplier: Int) -> Self {
        AccumulatedFeeBuilder(
            fees: extrinsicFees,
            multiplier: multiplier
        )
    }

    func build() throws -> ExtrinsicFeeProtocol {
        guard extrinsicFees.allSatisfy({ $0.payer == extrinsicFees.first?.payer }) else {
            throw AccumulatedFeeBuilderErrors.payerDiffers
        }

        let totalAmount = extrinsicFees
            .map(\.amount)
            .reduce(0, +)

        let totalRefTime = extrinsicFees
            .map(\.weight.refTime)
            .reduce(0, +)
        let totalProofSize = extrinsicFees
            .map(\.weight.proofSize)
            .reduce(0, +)

        let totalWeight = Substrate.Weight(
            refTime: totalRefTime,
            proofSize: totalProofSize
        )

        return ExtrinsicFee(
            amount: totalAmount,
            payer: extrinsicFees.first?.payer,
            weight: totalWeight
        )
    }
}

enum AccumulatedFeeBuilderErrors: Error {
    case payerDiffers
}
