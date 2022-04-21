import Foundation
import RobinHood

protocol DAppLocalSubscriptionHandler: AnyObject {
    func handleFavoriteDApps(result: Result<[DataProviderChange<DAppFavorite>], Error>)
    func handleAuthorizedDApps(result: Result<[DataProviderChange<DAppSettings>], Error>, for metaId: String)
}

extension DAppLocalSubscriptionHandler {
    func handleFavoriteDApps(
        result _: Result<[DataProviderChange<DAppFavorite>], Error>
    ) {}

    func handleAuthorizedDApps(
        result _: Result<[DataProviderChange<DAppSettings>], Error>,
        for _: String
    ) {}
}
