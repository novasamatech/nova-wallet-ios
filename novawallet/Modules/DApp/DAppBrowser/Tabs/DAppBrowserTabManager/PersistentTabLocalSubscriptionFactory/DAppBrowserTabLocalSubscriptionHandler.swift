import Foundation
import Operation_iOS

protocol DAppBrowserTabLocalSubscriptionHandler: AnyObject {
    func handleBrowserTabs(
        result: Result<[DataProviderChange<DAppBrowserTab.PersistenceModel>], Error>
    )
}

extension DAppBrowserTabLocalSubscriptionHandler {
    func handleBrowserTabs(
        result _: Result<[DataProviderChange<DAppBrowserTab.PersistenceModel>], Error>
    ) {}
}
