import Foundation

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
            let symbol = formatter.percentSymbol ?? "%"
            formatter.positivePrefix = formatter.positivePrefix.replacingOccurrences(of: symbol, with: "")
            formatter.negativePrefix = formatter.negativePrefix.replacingOccurrences(of: symbol, with: "")
            formatter.positiveSuffix = " " + symbol
            formatter.negativeSuffix = " " + symbol
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
