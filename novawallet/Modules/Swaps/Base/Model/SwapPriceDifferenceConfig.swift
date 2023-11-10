import Foundation

struct SwapPriceDifferenceConfig {
    let high: Decimal
    let medium: Decimal
    let low: Decimal
}

extension SwapPriceDifferenceConfig {
    static var defaultConfig: SwapPriceDifferenceConfig {
        .init(
            high: 0.15,
            medium: 0.05,
            low: 0.01
        )
    }
}
