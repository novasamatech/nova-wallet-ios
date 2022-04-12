import Foundation
import RobinHood

protocol DAppLocalSubscriptionHandler: AnyObject {
    func handleFavoriteDApps(result: Result<[DataProviderChange<DAppFavorite>], Error>)
}

extension DAppLocalSubscriptionHandler {
    func handleFavoriteDApps(
        result _: Result<[DataProviderChange<DAppFavorite>], Error>
    ) {}
}
