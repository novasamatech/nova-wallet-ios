import Foundation
import Foundation_iOS

enum SubtensorApyStyle: Equatable {
    case leading
    case trailing
    case paidInTao
    case bare
    case column
}

enum SubtensorApyFormatter {
    static func text(for annualRate: Decimal?, style: SubtensorApyStyle, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch style {
        case .leading:
            return strings.stakingSubtensorUiRateApyLeadingFormat(rateText(annualRate, locale: locale))
        case .trailing:
            return strings.stakingSubtensorUiRateApyTrailingFormat(rateText(annualRate, locale: locale))
        case .paidInTao:
            return strings.stakingSubtensorUiRatePaidInTaoFormat(rateText(annualRate, locale: locale))
        case .bare:
            return rateText(annualRate, locale: locale)
        case .column:
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.roundingMode = .halfEven
            formatter.locale = locale
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
            formatter.spacePercentSymbol()
            return rateText(annualRate, formatter: formatter, locale: locale)
        }
    }
}

private extension SubtensorApyFormatter {
    static func rateText(
        _ annualRate: Decimal?,
        formatter: NumberFormatter = NumberFormatter.percentSingle,
        locale: Locale
    ) -> String {
        formatter.locale = locale

        return annualRate.flatMap { formatter.stringFromDecimal($0) } ??
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()
    }
}

extension NumberFormatter {
    static var subtensorPercentSingle: LocalizableResource<NumberFormatter> {
        LocalizableResource { locale in
            let formatter = NumberFormatter.percentSingle
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
