import Foundation

public extension AnalyticsEvent {
    static func sendInitiated(
        asset: AnalyticsContentValue,
        network: AnalyticsContentValue,
        destinationNetwork: AnalyticsContentValue?,
        amount: Decimal,
        rate: Decimal?,
        isCrossChain: Bool
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .sendInitiated,
            properties: [
                .asset: asset,
                .network: network,
                .destinationNetwork: destinationNetwork,
                .assetCategory: AssetCategoryClassifier.classify(asset.stringValue),
                .amountBucket: AmountBucket(amount: amount, rate: rate),
                .isCrossChain: isCrossChain
            ]
        )
    }

    static func sendCompleted(
        asset: AnalyticsContentValue,
        network: AnalyticsContentValue,
        destinationNetwork: AnalyticsContentValue?,
        amount: Decimal,
        rate: Decimal?
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .sendCompleted,
            properties: [
                .asset: asset,
                .network: network,
                .destinationNetwork: destinationNetwork,
                .amountBucket: AmountBucket(amount: amount, rate: rate)
            ]
        )
    }

    static func sendFailed(
        asset: AnalyticsContentValue,
        network: AnalyticsContentValue,
        destinationNetwork: AnalyticsContentValue?,
        reason: TransactionFailureReason
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .sendFailed,
            properties: [
                .asset: asset,
                .network: network,
                .destinationNetwork: destinationNetwork,
                .reason: reason
            ]
        )
    }
}
