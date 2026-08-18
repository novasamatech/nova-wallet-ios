import Foundation
import BigInt

enum HydraFeeConversion {
    struct Price: Equatable {
        let inner: BigUInt

        static let one = Price(inner: BigRational.fixedU128Divisor)
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
