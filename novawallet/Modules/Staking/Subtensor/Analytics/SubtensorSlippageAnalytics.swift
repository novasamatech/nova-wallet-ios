import Foundation
import NovaAnalytics

struct SubtensorSlippageAnalytics: AnalyticsTracking {
    let config: SlippageConfig

    func trackChange(from initial: BigRational?, to value: BigRational) {
        guard let bucket = value.analyticsSlippageBucket else {
            return
        }

        trackAnalytics(
            .slippageChanged(method: method(from: initial, to: value), slippage: bucket, warning: warning(for: value))
        )
    }
}

private extension SubtensorSlippageAnalytics {
    func method(from initial: BigRational?, to value: BigRational) -> SlippageChangeMethod {
        let newValue = value.decimalOrZeroValue
        let defaultValue = config.defaultSlippage.decimalOrZeroValue

        if newValue == defaultValue, initial?.decimalOrZeroValue != defaultValue {
            return .reset
        }

        return config.slippageTips.contains { $0.decimalOrZeroValue == newValue } ? .preset : .custom
    }

    func warning(for value: BigRational) -> SlippageWarning {
        let newValue = value.decimalOrZeroValue

        if newValue < config.smallSlippage.decimalOrZeroValue {
            return .mayRevert
        }

        if newValue > config.bigSlippage.decimalOrZeroValue {
            return .mayFrontrun
        }

        return .none
    }
}
