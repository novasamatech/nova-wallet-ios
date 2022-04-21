import Foundation

protocol DAppListViewModelFactoryProtocol {
    func createFavoriteDAppName(from model: DAppFavorite) -> String

    func createFavoriteDApps(from list: [DAppFavorite]) -> [DAppViewModel]

    func createDApps(
        from category: String?,
        dAppList: DAppList,
        favorites: [String: DAppFavorite]
    ) -> [DAppViewModel]

    func createDAppsFromQuery(
        _ query: String?,
        dAppList: DAppList,
        favorites: [String: DAppFavorite]
    ) -> [DAppViewModel]
}

private typealias IndexedDApp = (index: Int, dapp: DApp)

final class DAppListViewModelFactory {
    private func createDAppViewModel(
        from model: DApp,
        index: Int,
        categories: [String: DAppCategory],
        favorite: Bool
    ) -> DAppViewModel {
        let imageViewModel: ImageViewModelProtocol

        if let iconUrl = model.icon {
            imageViewModel = RemoteImageViewModel(url: iconUrl)
        } else {
            imageViewModel = StaticImageViewModel(image: R.image.iconDefaultDapp()!)
        }

        let details = model.categories.map {
            categories[$0]?.name ?? $0
        }.joined(separator: ", ")

        return DAppViewModel(
            identifier: .index(value: index),
            name: model.name,
            details: details,
            icon: imageViewModel,
            isFavorite: favorite
        )
    }

    private func createFavoriteDAppViewModel(from model: DAppFavorite) -> DAppViewModel {
        let imageViewModel: ImageViewModelProtocol

        if let icon = model.icon, let url = URL(string: icon) {
            imageViewModel = RemoteImageViewModel(url: url)
        } else {
            imageViewModel = StaticImageViewModel(image: R.image.iconDefaultDapp()!)
        }

        let name = createFavoriteDAppName(from: model)

        return DAppViewModel(
            identifier: .key(value: model.identifier),
            name: name,
            details: model.identifier,
            icon: imageViewModel,
            isFavorite: true
        )
    }

    private func createViewModels(
        merging dapps: [IndexedDApp],
        filteredFavorites: [String: DAppFavorite],
        allFavorites: [String: DAppFavorite],
        categories: [DAppCategory]
    ) -> [DAppViewModel] {
        let categoriesDict = categories.reduce(into: [String: DAppCategory]()) { result, category in
            result[category.identifier] = category
        }

        let knownIdentifiers = Set(dapps.map(\.dapp.identifier))

        let knownViewModels: [DAppViewModel] = dapps.map { indexedDapp in
            let favorite = allFavorites[indexedDapp.dapp.identifier] != nil
            return createDAppViewModel(
                from: indexedDapp.dapp,
                index: indexedDapp.index,
                categories: categoriesDict,
                favorite: favorite
            )
        }

        let favoriteViewModels = filteredFavorites.values.filter {
            !knownIdentifiers.contains($0.identifier)
        }.map { createFavoriteDAppViewModel(from: $0) }

        let allViewModels = favoriteViewModels + knownViewModels

        return allViewModels.sorted { model1, model2 in
            let favoriteValue1 = model1.isFavorite ? 1 : 0
            let favoriteValue2 = model2.isFavorite ? 1 : 0

            if favoriteValue1 != favoriteValue2 {
                return favoriteValue1 > favoriteValue2
            } else if let order1 = model1.order, let order2 = model2.order {
                return order1 < order2
            } else if model1.order != nil {
                return false
            } else if model2.order != nil {
                return true
            } else {
                return model1.name.localizedCompare(model2.name) == .orderedAscending
            }
        }
    }
}

extension DAppListViewModelFactory: DAppListViewModelFactoryProtocol {
    func createFavoriteDAppName(from model: DAppFavorite) -> String {
        if let label = model.label {
            return label
        } else if let url = URL(string: model.identifier) {
            return url.host ?? model.identifier
        } else {
            return model.identifier
        }
    }

    func createFavoriteDApps(from list: [DAppFavorite]) -> [DAppViewModel] {
        list.map { favoriteDapp in
            createFavoriteDAppViewModel(from: favoriteDapp)
        }
    }

    func createDApps(
        from category: String?,
        dAppList: DAppList,
        favorites: [String: DAppFavorite]
    ) -> [DAppViewModel] {
        let actualDApps: [IndexedDApp] = dAppList.dApps.enumerated().compactMap { valueIndex in
            if let category = category {
                return valueIndex.element.categories.contains(category) ?
                    IndexedDApp(index: valueIndex.offset, dapp: valueIndex.element) : nil
            } else {
                return IndexedDApp(index: valueIndex.offset, dapp: valueIndex.element)
            }
        }

        if category == nil {
            return createViewModels(
                merging: actualDApps,
                filteredFavorites: favorites,
                allFavorites: favorites,
                categories: dAppList.categories
            )
        } else {
            return createViewModels(
                merging: actualDApps,
                filteredFavorites: [:],
                allFavorites: favorites,
                categories: dAppList.categories
            )
        }
    }

    func createDAppsFromQuery(
        _ query: String?,
        dAppList: DAppList,
        favorites: [String: DAppFavorite]
    ) -> [DAppViewModel] {
        let actualDApps: [IndexedDApp] = dAppList.dApps.enumerated().compactMap { valueIndex in
            guard let query = query, !query.isEmpty else {
                return IndexedDApp(index: valueIndex.offset, dapp: valueIndex.element)
            }

            if valueIndex.element.name.localizedCaseInsensitiveContains(query) {
                return IndexedDApp(index: valueIndex.offset, dapp: valueIndex.element)
            } else {
                return nil
            }
        }

        let filteredFavorites = favorites.filter { keyValue in
            guard let query = query, !query.isEmpty else {
                return true
            }

            let name = createFavoriteDAppName(from: keyValue.value)
            return name.localizedCaseInsensitiveContains(query)
        }

        return createViewModels(
            merging: actualDApps,
            filteredFavorites: filteredFavorites,
            allFavorites: favorites,
            categories: dAppList.categories
        )
    }
}
