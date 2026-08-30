import Foundation

/// What a pool says about one hop of a quoted route.
///
/// Both payload fields are optional because a violation is worth blocking on even when it cannot be
/// described: an Omnipool cap needs a probe through the pool math and is sometimes underivable, and
/// the asset can only be resolved one layer out, at the edge. Blocking never depends on either.
struct AssetExchangeTradeLimitBreach: Equatable {
    /// The exact runtime threshold on the hop's *given* amount, with no headroom. `nil` when the pool
    /// admits no closed-form cap.
    let maxGivenAmount: Balance?

    /// `MinTradingLimit`. `nil` when the constant is absent, which suppresses the suggestion without
    /// affecting the block.
    let minTradingLimit: Balance?

    /// The pool asset the cap is denominated in. `nil` until an edge names it.
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
