import Foundation
import NovaAnalytics

extension BannersPresenter: AnalyticsTracking {
    func trackBannerClicked(with id: String) {
        let event = AnalyticsContentValue.bannerId(id).map { bannerId in
            AnalyticsEvent.bannerClicked(id: bannerId, screen: domain.analyticsScreen)
        }

        trackAnalytics(event)
    }
}

// MARK: Banners.Domain

extension Banners.Domain {
    var analyticsScreen: AnalyticsBannerScreen {
        switch self {
        case .dApps:
            .dApps
        case .assets:
            .assets
        case .ahmKusama:
            .ahmKusama
        case .ahmPolkadot:
            .ahmPolkadot
        }
    }
}
