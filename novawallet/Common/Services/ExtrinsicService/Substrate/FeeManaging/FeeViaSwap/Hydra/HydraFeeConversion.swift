import Foundation
import BigInt

enum HydraFeeConversion {
    struct Price: Equatable {
        static let divisor: BigUInt = 1_000_000_000_000_000_000

        static let one = Price(inner: divisor)

        let inner: BigUInt

        init(inner: BigUInt) {
            self.inner = inner
        }

        init?(rational: BigRational) {
            guard rational.denominator > 0 else {
                return nil
            }

            let (quotient, remainder) = (Self.divisor * rational.numerator)
                .quotientAndRemainder(dividingBy: rational.denominator)

            let rounded = remainder > rational.denominator / 2 ? quotient + 1 : quotient

            guard rounded.bitWidth <= 128 else {
                return nil
            }

            inner = rounded
        }
    }

    static func convertFee(_ nativeFee: BigUInt, price: Price) -> BigUInt {
        guard nativeFee > 0 else {
            return 0
        }

        return max(BigRational.fixedU128(value: price.inner).mul(value: nativeFee), 1)
    }
}

enum HydraFeeOraclePriceError: Error {
    case assetNotAcceptedAsFee(ChainAssetId)
}
