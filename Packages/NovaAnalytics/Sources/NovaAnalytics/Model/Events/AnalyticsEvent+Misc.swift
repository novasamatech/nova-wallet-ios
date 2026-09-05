import Foundation

public extension AnalyticsEvent {
    /// Emitted only when the banner carries an action link. Android's third key
    /// `banner_title` has no iOS source and is omitted.
    static func bannerClicked(
        id: AnalyticsContentValue,
        screen: AnalyticsBannerScreen
    ) -> AnalyticsEvent {
        AnalyticsEvent(name: .bannerClicked, properties: [.bannerId: id, .screen: screen])
    }
}
