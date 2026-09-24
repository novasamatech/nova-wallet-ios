import Foundation
import NovaAnalytics

extension DAppSearchPresenter: AnalyticsTracking {
    func trackDAppRowOpened(with result: DAppSearchResult) {
        let optUrl: URL? = switch result {
        case let .dApp(dApp):
            dApp.url
        case let .query(identifier):
            URL(string: identifier)
        }

        guard let url = optUrl else {
            return
        }

        let isKnown = switch result {
        case .dApp:
            true
        case .query:
            dAppList?.dApps.contains { URL.hostsEqual($0.url, url) } ?? false
        }

        trackDAppOpened(
            url: url,
            source: .search,
            isKnown: isKnown
        )
    }

    func trackSearchQueryOpened(_ searchQuery: String) {
        guard let url = DAppBrowserTab.resolveUrl(for: searchQuery) else {
            return
        }

        let isManualUrl = NSPredicate.urlPredicate.evaluate(with: searchQuery)
        let isKnown = isManualUrl && (dAppList?.dApps.contains { URL.hostsEqual($0.url, url) } ?? false)

        trackDAppOpened(
            url: url,
            source: isManualUrl ? .manualUrl : .search,
            isKnown: isKnown
        )
    }
}
