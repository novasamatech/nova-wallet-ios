import Foundation

struct SlippageBounds {
    let restriction: BoundValue
    let recommendation: BoundValue

    struct BoundValue {
        let lower: Decimal
        let upper: Decimal
    }

    init(config: SlippageConfig) {
        restriction = .init(
            lower: config.minAvailableSlippage.toPercents().decimalOrZeroValue,
            upper: config.maxAvailableSlippage.toPercents().decimalOrZeroValue
        )

        recommendation = .init(
            lower: config.smallSlippage.toPercents().decimalOrZeroValue,
            upper: config.bigSlippage.toPercents().decimalOrZeroValue
        )
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
