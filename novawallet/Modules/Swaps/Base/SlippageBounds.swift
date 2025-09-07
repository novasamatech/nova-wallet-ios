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
            lower: config.minAvailableSlippage.decimalOrZeroValue,
            upper: config.maxAvailableSlippage.decimalOrZeroValue
        )

        recommendation = .init(
            lower: config.smallSlippage.decimalOrZeroValue,
            upper: config.bigSlippage.decimalOrZeroValue
        )
    }
}

extension SlippageBounds {
    func warning(for value: Decimal?, locale: Locale) -> String? {
        guard let value = value, value > 0 else {
            return nil
        }
        if value < recommendation.lower {
            let warning = R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupSlippageWarningLowAmount()
            return warning
        } else if value > recommendation.upper {
            let warning = R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupSlippageWarningHighAmount()
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
            let error = R.string(preferredLanguages: locale.rLanguages
            ).localizable.swapsSetupSlippageErrorAmountBounds(minAmountString, maxAmountString)
            return error
        } else {
            return nil
        }
    }
}
