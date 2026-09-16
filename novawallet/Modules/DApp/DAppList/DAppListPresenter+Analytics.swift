import Foundation
import NovaAnalytics

extension DAppListPresenter: AnalyticsTracking {
    func trackOpened(dAppId: String) {
        guard let url = URL(string: dAppId) else {
            return
        }

        let isKnown: Bool = if case let .success(list) = dAppsResult {
            list.dApps.contains { $0.identifier == dAppId }
        } else {
            false
        }

        trackDAppOpened(
            url: url,
            source: .catalog,
            isKnown: isKnown
        )
    }
}
