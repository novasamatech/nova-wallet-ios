import Foundation

extension AmountInputViewModel {
    static func forAssetConversionSlippage(for amount: Decimal?, locale: Locale) -> AmountInputViewModel {
        let precision: Int16 = 4
        let numberFormatter = NumberFormatter.amount.localizableResource().value(for: locale)
        numberFormatter.maximumFractionDigits = Int(precision)
        numberFormatter.maximumSignificantDigits = Int(precision)

        return .init(
            symbol: "",
            amount: amount,
            limit: 100,
            formatter: numberFormatter,
            precision: precision
        )
    }
}
