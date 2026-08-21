import Foundation
import BigInt
import HydraMathApi

enum HydraEmaPriceMath {
    static func iteratedPrice(
        previous: BigRational,
        incoming: BigRational,
        iterations: BlockNumber,
        smoothing: BigUInt
    ) -> BigRational? {
        let result = HydraEmaMath.emaIteratedPrice(
            String(previous.numerator),
            String(previous.denominator),
            String(incoming.numerator),
            String(incoming.denominator),
            iterations,
            String(smoothing)
        ).toString()

        let components = result.split(separator: ",")

        guard
            components.count == 2,
            let numerator = BigUInt(String(components[0])),
            let denominator = BigUInt(String(components[1])) else {
            return nil
        }

        return BigRational(numerator: numerator, denominator: denominator)
    }
}
