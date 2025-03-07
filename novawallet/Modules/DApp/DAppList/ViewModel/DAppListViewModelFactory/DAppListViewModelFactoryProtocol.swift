import Foundation
import SubstrateSdk

protocol DAppListViewModelFactoryProtocol {
    func createFavoriteDAppName(from model: DAppFavorite) -> String

    func createFavoriteDApps(
        from list: [DAppFavorite],
        dAppList: DAppList
    ) -> [DAppViewModel]

    func createDApps(
        from category: String?,
        query: String?,
        dAppList: DAppList,
        favorites: [String: DAppFavorite]
    ) -> DAppListViewModel

    func createErrorSection() -> DAppListSectionViewModel

    func createDAppSections(
        from dAppList: DAppList?,
        favorites: [String: DAppFavorite],
        wallet: MetaAccountModel?,
        params: DAppListViewModelFactory.ListSectionsParams,
        bannersState: BannersState,
        locale: Locale
    ) -> [DAppListSectionViewModel]
}

extension DAppListViewModelFactoryProtocol {
    func createDApps(
        from category: String?,
        dAppList: DAppList,
        favorites: [String: DAppFavorite]
    ) -> DAppListViewModel {
        createDApps(
            from: category,
            query: nil,
            dAppList: dAppList,
            favorites: favorites
        )
    }
}
