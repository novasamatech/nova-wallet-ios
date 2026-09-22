import Foundation

public extension AnalyticsEvent {
    static func bannerClicked(
        id: AnalyticsContentValue,
        screen: AnalyticsBannerScreen
    ) -> AnalyticsEvent {
        AnalyticsEvent(name: .bannerClicked, properties: [.bannerId: id, .screen: screen])
    }
}
