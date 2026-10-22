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
    static var subtensorPercent: LocalizableResource<NumberFormatter> { NumberFormatter.percent.localizableResource() }

    static var subtensorSignedPercentSingle: LocalizableResource<NumberFormatter> {
        NumberFormatter.signedPercentSingle.localizableResource()
    }

    static var subtensorPercentSingle: LocalizableResource<NumberFormatter> {
        NumberFormatter.percentSingle.localizableResource()
    }

    static var subtensorPercentSingleHalfEven: LocalizableResource<NumberFormatter> {
        NumberFormatter.percentSingleHalfEven.localizableResource()
    }
}
