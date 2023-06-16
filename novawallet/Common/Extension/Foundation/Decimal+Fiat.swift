import Foundation
import BigInt

extension Decimal {
    static func fiatValue(
        from balance: BigUInt?,
        price: PriceData?,
        precision: Int16
    ) -> Decimal {
        guard let balance = balance,
              let rate = price?.decimalRate else {
            return 0
        }

        let decimalBalance = Decimal.fromSubstrateAmount(
            balance,
            precision: precision
        ) ?? 0

        return decimalBalance * rate
    }
}
