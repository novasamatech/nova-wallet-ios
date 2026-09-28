import Foundation

enum SubtensorApyStyle: Equatable {
    case leading
    case trailing
    case paidInTao
    case bare
    case column
}

enum SubtensorApyFormatter {
    static func text(for annualRate: Decimal, style: SubtensorApyStyle, locale: Locale) -> String {
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
            return rateText(annualRate, formatter: NumberFormatter.percent, locale: locale)
        }
    }
}

private extension SubtensorApyFormatter {
    static func rateText(
        _ annualRate: Decimal,
        formatter: NumberFormatter = NumberFormatter.percentSingle,
        locale: Locale
    ) -> String {
        formatter.locale = locale

        return formatter.stringFromDecimal(annualRate) ??
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()
    }
}
