import Foundation
import Operation_iOS

/// An edge whose pool limits the size of a single trade — Hydration's XYK and Omnipool pallets reject
/// a trade consuming more than `reserve / MaxInRatio` of either side. Mirrors Android's
/// `TradeAmountLimitedEdge`, with a verdict in place of a nullable cap: a cap that cannot be derived
/// must still block, and a nullable cap has no way to say that.
///
/// `amount` is the hop's *given* amount — its input for `.sell`, its output for `.buy`.
protocol AssetExchangeTradeLimitedEdge {
    func tradeLimitVerdict(
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeTradeLimitVerdict>
}
