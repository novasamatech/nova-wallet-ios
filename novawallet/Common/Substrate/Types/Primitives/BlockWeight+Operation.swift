import Foundation
import BigInt

extension Substrate.WeightV2 {
    static let maxDimension = BigUInt(UInt64.max)

    func anyGt(then other: Self) -> Bool {
        refTime > other.refTime || proofSize > other.proofSize
    }

    func fits(in other: Self) -> Bool {
        !anyGt(then: other)
    }

    static var zero: Self {
        Substrate.WeightV2(refTime: 0, proofSize: 0)
    }

    static var one: Self {
        Substrate.WeightV2(refTime: 1, proofSize: 1)
    }

    static var maxWeight: Self {
        Substrate.WeightV2(refTime: Self.maxDimension, proofSize: Self.maxDimension)
    }

    func minByComponent(with other: Self) -> Self {
        Substrate.WeightV2(
            refTime: min(refTime, other.refTime),
            proofSize: min(proofSize, other.proofSize)
        )
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        Substrate.WeightV2(
            refTime: lhs.refTime + rhs.refTime,
            proofSize: lhs.proofSize + rhs.proofSize
        )
    }

    static func += (lhs: inout Self, rhs: Self) {
        lhs = Substrate.WeightV2(
            refTime: lhs.refTime + rhs.refTime,
            proofSize: lhs.proofSize + rhs.proofSize
        )
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        Substrate.WeightV2(
            refTime: lhs.refTime.subtractOrZero(rhs.refTime),
            proofSize: lhs.proofSize.subtractOrZero(rhs.proofSize)
        )
    }

    static func * (lhs: Self, rhs: BigRational) -> Self {
        Substrate.WeightV2(
            refTime: rhs.mul(value: lhs.refTime),
            proofSize: rhs.mul(value: lhs.proofSize)
        )
    }
}
