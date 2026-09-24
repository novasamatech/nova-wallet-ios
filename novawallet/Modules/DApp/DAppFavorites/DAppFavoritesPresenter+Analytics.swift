import Foundation
import NovaAnalytics

extension DAppFavoritesPresenter: AnalyticsTracking {
    func trackOpened(dAppId: String) {
        guard let url = URL(string: dAppId) else {
            return
        }

        let isKnown = dAppList?.dApps.contains { $0.identifier == dAppId } ?? false

        trackDAppOpened(
            url: url,
            source: .favorites,
            isKnown: isKnown
        )
    }
}
