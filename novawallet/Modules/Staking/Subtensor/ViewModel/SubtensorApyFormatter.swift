import Foundation
import Foundation_iOS

enum SubtensorApyStyle: Equatable {
    case leading
    case trailing
    case paidInTao
    case bare
}

enum SubtensorApyFormatter {
    static func text(for annualRate: Decimal?, style: SubtensorApyStyle, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let rate = annualRate.flatMap { NumberFormatter.subtensorPercent.value(for: locale).stringFromDecimal($0) } ??
            strings.stakingSubtensorUiValueUnknown()

        switch style {
        case .leading:
            return strings.stakingSubtensorUiRateApyLeadingFormat(rate)
        case .trailing:
            return strings.stakingSubtensorUiRateApyTrailingFormat(rate)
        case .paidInTao:
            return strings.stakingSubtensorUiRatePaidInTaoFormat(rate)
        case .bare:
            return rate
        }
    }
}

extension NumberFormatter {
    static var subtensorPercent: LocalizableResource<NumberFormatter> { spaced(.percent) }

    static var subtensorSignedPercentSingle: LocalizableResource<NumberFormatter> { spaced(.signedPercentSingle) }

    static var subtensorPercentSingle: LocalizableResource<NumberFormatter> { spaced(.percentSingle) }

    static var subtensorPercentSingleHalfEven: LocalizableResource<NumberFormatter> { spaced(.percentSingleHalfEven) }

    private static func spaced(
        _ makeFormatter: @escaping @autoclosure () -> NumberFormatter
    ) -> LocalizableResource<NumberFormatter> {
        LocalizableResource { locale in
            let formatter = makeFormatter()
            formatter.locale = locale
            formatter.spacePercentSymbol()
            return formatter
        }
    }

    func spacePercentSymbol() {
        let symbol = percentSymbol ?? "%"
        positivePrefix = positivePrefix.replacingOccurrences(of: symbol, with: "")
        negativePrefix = negativePrefix.replacingOccurrences(of: symbol, with: "")
        positiveSuffix = " " + symbol
        negativeSuffix = " " + symbol
    }
}
