import Foundation
import BigInt

extension Substrate.WeightV2 {
    static func + (lhs: Substrate.WeightV2, rhs: Substrate.WeightV2) -> Substrate.WeightV2 {
        Substrate.WeightV2(
            refTime: lhs.refTime + rhs.refTime,
            proofSize: lhs.proofSize + rhs.proofSize
        )
    }

    static func - (lhs: Substrate.WeightV2, rhs: Substrate.WeightV2) -> Substrate.WeightV2 {
        Substrate.WeightV2(
            refTime: lhs.refTime.subtractOrZero(rhs.refTime),
            proofSize: lhs.proofSize.subtractOrZero(rhs.refTime)
        )
    }

    static func * (lhs: Substrate.WeightV2, rhs: BigRational) -> Substrate.WeightV2 {
        Substrate.WeightV2(
            refTime: rhs.mul(value: lhs.refTime),
            proofSize: rhs.mul(value: lhs.proofSize)
        )
    }
}
