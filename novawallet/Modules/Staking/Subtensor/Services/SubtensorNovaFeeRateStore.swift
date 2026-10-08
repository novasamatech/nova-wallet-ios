import Foundation

final class SubtensorNovaFeeRateStore {
    static let shared = SubtensorNovaFeeRateStore()

    @Atomic(defaultValue: nil)
    private var configuredRate: BigRational?

    var rate: BigRational {
        configuredRate ?? SubtensorNovaFeeConstants.fallbackRate
    }

    func apply(_ config: SubtensorConfig) {
        configuredRate = config.novaFeeRate
    }
}
