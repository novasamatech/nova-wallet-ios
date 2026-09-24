import Foundation

struct AssetExchangeTradeLimitBreach: Equatable {
    let maxGivenAmount: Balance?

    let minTradingLimit: Balance?

    let limitedAsset: ChainAsset?

    init(
        maxGivenAmount: Balance?,
        minTradingLimit: Balance?,
        limitedAsset: ChainAsset? = nil
    ) {
        self.maxGivenAmount = maxGivenAmount
        self.minTradingLimit = minTradingLimit
        self.limitedAsset = limitedAsset
    }

    func naming(limitedAsset: ChainAsset) -> AssetExchangeTradeLimitBreach {
        .init(
            maxGivenAmount: maxGivenAmount,
            minTradingLimit: minTradingLimit,
            limitedAsset: limitedAsset
        )
    }
}

enum AssetExchangeTradeLimitVerdict: Equatable {
    case withinLimit
    case exceeds(AssetExchangeTradeLimitBreach)

    func naming(limitedAsset: ChainAsset) -> AssetExchangeTradeLimitVerdict {
        switch self {
        case .withinLimit:
            .withinLimit
        case let .exceeds(breach):
            .exceeds(breach.naming(limitedAsset: limitedAsset))
        }
    }
}
