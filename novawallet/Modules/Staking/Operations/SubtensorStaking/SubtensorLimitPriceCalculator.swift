import BigInt
import Foundation

enum SubtensorSlippageTolerance {
    static let presets: [BigRational] = [
        BigRational(numerator: 1, denominator: 1000),
        BigRational(numerator: 5, denominator: 1000),
        BigRational(numerator: 1, denominator: 100),
        BigRational(numerator: 3, denominator: 100)
    ]

    static let defaultTolerance = BigRational(numerator: 5, denominator: 1000)
}

enum SubtensorLimitPriceError: Error, Equatable {
    case zeroSpot
    case invalidTolerance
    case zeroLimit
}

enum SubtensorLimitPriceCalculator {
    static func buyLimit(spot: Balance, tolerance: BigRational) throws -> Balance {
        guard tolerance.denominator > 0 else {
            throw SubtensorLimitPriceError.invalidTolerance
        }

        guard spot > 0 else {
            throw SubtensorLimitPriceError.zeroSpot
        }

        let flooredLimit = spot + spot * tolerance.numerator / tolerance.denominator

        // the chain's buy gate is strictly current < limit against a floor-truncated wire
        // spot, so a limit equal to spot can never pass — bump to the tightest usable limit
        let limit = max(flooredLimit, spot + 1)

        try SubtensorStakingPallet.ensureU64Amount(limit)

        return limit
    }

    static func sellLimit(spot: Balance, tolerance: BigRational) throws -> Balance {
        guard tolerance.denominator > 0, tolerance.numerator < tolerance.denominator else {
            throw SubtensorLimitPriceError.invalidTolerance
        }

        guard spot > 0 else {
            throw SubtensorLimitPriceError.zeroSpot
        }

        let retained = tolerance.denominator - tolerance.numerator
        let ceiledLimit = (spot * retained + tolerance.denominator - 1) / tolerance.denominator

        // sell gate is strictly current > limit — cap at spot − 1 so an unmoved price executes
        let limit = min(ceiledLimit, spot - 1)

        guard limit > 0 else {
            throw SubtensorLimitPriceError.zeroLimit
        }

        try SubtensorStakingPallet.ensureU64Amount(limit)

        return limit
    }
}
