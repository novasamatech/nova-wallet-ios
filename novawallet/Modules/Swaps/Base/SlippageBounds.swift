import Foundation

struct SlippageBounds {
    let restriction: BoundValue = .init(lower: 0.1, upper: 50)
    let recommendation: BoundValue = .init(lower: 0.1, upper: 5)

    struct BoundValue {
        let lower: Decimal
        let upper: Decimal
    }
}

extension SlippageBounds {
    func warning(for value: Decimal?, locale: Locale) -> String? {
        guard let value = value, value > 0 else {
            return nil
        }
        if value <= recommendation.lower {
            let warning = R.string.localizable.swapsSetupSlippageWarningLowAmount(
                preferredLanguages: locale.rLanguages
            )
            return warning
        } else if value >= recommendation.upper {
            let warning = R.string.localizable.swapsSetupSlippageWarningHighAmount(
                preferredLanguages: locale.rLanguages
            )
            return warning
        } else {
            return nil
        }
    }

    func error(for value: Decimal?, stringAmountClosure: (Decimal) -> String, locale: Locale) -> String? {
        if let value = value,
           value < restriction.lower || value > restriction.upper {
            let minAmountString = stringAmountClosure(restriction.lower)
            let maxAmountString = stringAmountClosure(restriction.upper)
            let error = R.string.localizable.swapsSetupSlippageErrorAmountBounds(
                minAmountString,
                maxAmountString,
                preferredLanguages: locale.rLanguages
            )
            return error
        } else {
            return nil
        }
    }
}
