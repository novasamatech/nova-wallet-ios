import Foundation

struct SwapPriceDifferenceConfig {
    let warningMin: Decimal
    let warningMax: Decimal
}

extension SwapPriceDifferenceConfig {
    static var defaultConfig: SwapPriceDifferenceConfig {
        .init(
            warningMin: 0.1,
            warningMax: 0.2
        )
    }
}
