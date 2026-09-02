import Foundation

extension AnalyticsEvent {
    static func swapScreenOpened(source: SwapSource) -> AnalyticsEvent {
        AnalyticsEvent(name: .swapScreenOpened, properties: [.source: source])
    }

    /// Failable, because Android skips swap events without a fiat rate for the pay asset.
    static func swapInitiated(
        source: SwapSource,
        assetIn: AnalyticsContentValue,
        assetOut: AnalyticsContentValue,
        networkIn: AnalyticsContentValue,
        networkOut: AnalyticsContentValue,
        amount: Decimal,
        price: PriceData?
    ) -> AnalyticsEvent? {
        guard let amountBucket = AmountBucket(amount: amount, price: price) else {
            return nil
        }

        return AnalyticsEvent(
            name: .swapInitiated,
            properties: [
                .source: source,
                .assetIn: assetIn,
                .assetOut: assetOut,
                .networkIn: networkIn,
                .networkOut: networkOut,
                .assetInCategory: AssetCategoryClassifier.classify(assetIn.stringValue),
                .assetOutCategory: AssetCategoryClassifier.classify(assetOut.stringValue),
                .amountBucket: amountBucket
            ]
        )
    }

    static func swapConfirmed(
        assetIn: AnalyticsContentValue,
        assetOut: AnalyticsContentValue,
        networkIn: AnalyticsContentValue,
        networkOut: AnalyticsContentValue,
        amount: Decimal,
        price: PriceData?,
        slippage: Decimal
    ) -> AnalyticsEvent? {
        guard let amountBucket = AmountBucket(amount: amount, price: price) else {
            return nil
        }

        return AnalyticsEvent(
            name: .swapConfirmed,
            properties: [
                .assetIn: assetIn,
                .assetOut: assetOut,
                .networkIn: networkIn,
                .networkOut: networkOut,
                .amountBucket: amountBucket,
                .slippageBucket: SlippageBucket(percent: slippage)
            ]
        )
    }

    static func swapCompleted(
        assetIn: AnalyticsContentValue,
        assetOut: AnalyticsContentValue,
        networkIn: AnalyticsContentValue,
        networkOut: AnalyticsContentValue,
        amount: Decimal,
        price: PriceData?,
        duration: TimeInterval
    ) -> AnalyticsEvent? {
        guard let amountBucket = AmountBucket(amount: amount, price: price) else {
            return nil
        }

        return AnalyticsEvent(
            name: .swapCompleted,
            properties: [
                .assetIn: assetIn,
                .assetOut: assetOut,
                .networkIn: networkIn,
                .networkOut: networkOut,
                .amountBucket: amountBucket,
                .durationBucket: DurationBucket(duration: duration)
            ]
        )
    }

    static func swapFailed(reason: SwapFailureReason) -> AnalyticsEvent {
        AnalyticsEvent(name: .swapFailed, properties: [.reason: reason])
    }

    static func swapAbandoned(stage: SwapStage) -> AnalyticsEvent {
        AnalyticsEvent(name: .swapAbandoned, properties: [.stage: stage])
    }
}
