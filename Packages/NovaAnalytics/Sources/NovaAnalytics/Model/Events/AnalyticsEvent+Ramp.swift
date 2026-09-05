import Foundation

public extension AnalyticsEvent {
    static func buyInitiated(
        provider: AnalyticsContentValue,
        asset: AnalyticsContentValue,
        network: AnalyticsContentValue
    ) -> AnalyticsEvent {
        rampEvent(name: .buyInitiated, provider: provider, asset: asset, network: network)
    }

    static func buyCompleted(
        provider: AnalyticsContentValue,
        asset: AnalyticsContentValue,
        network: AnalyticsContentValue
    ) -> AnalyticsEvent {
        rampEvent(name: .buyCompleted, provider: provider, asset: asset, network: network)
    }

    static func sellInitiated(
        provider: AnalyticsContentValue,
        asset: AnalyticsContentValue,
        network: AnalyticsContentValue
    ) -> AnalyticsEvent {
        rampEvent(name: .sellInitiated, provider: provider, asset: asset, network: network)
    }

    static func sellCompleted(
        provider: AnalyticsContentValue,
        asset: AnalyticsContentValue,
        network: AnalyticsContentValue
    ) -> AnalyticsEvent {
        rampEvent(name: .sellCompleted, provider: provider, asset: asset, network: network)
    }
}

private extension AnalyticsEvent {
    static func rampEvent(
        name: AnalyticsEventName,
        provider: AnalyticsContentValue,
        asset: AnalyticsContentValue,
        network: AnalyticsContentValue
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: name,
            properties: [.provider: provider, .asset: asset, .network: network]
        )
    }
}
