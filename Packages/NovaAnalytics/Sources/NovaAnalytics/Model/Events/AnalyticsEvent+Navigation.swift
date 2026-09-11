import Foundation

public extension AnalyticsEvent {
    static func featureOpened(_ feature: FeatureId) -> AnalyticsEvent {
        AnalyticsEvent(name: .featureOpened, properties: [.featureId: feature])
    }

    static func tabSwitched(tab: AnalyticsTab) -> AnalyticsEvent {
        AnalyticsEvent(name: .tabSwitched, properties: [.tab: tab])
    }

    static func novaCardOpened() -> AnalyticsEvent {
        AnalyticsEvent(name: .novaCardOpened)
    }

    static func nftSectionOpened(count: NftCountBucket) -> AnalyticsEvent {
        AnalyticsEvent(name: .nftSectionOpened, properties: [.nftCountBucket: count])
    }
}
