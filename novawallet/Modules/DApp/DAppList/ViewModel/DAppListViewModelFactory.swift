import Foundation

protocol DAppListViewModelFactoryProtocol {
    func createFavoriteDAppName(from model: DAppFavorite) -> String

    func createFavoriteDApps(from list: [DAppFavorite]) -> [DAppViewModel]

    func createDApps(
        from category: String?,
        dAppList: DAppList,
        favorites: [String: DAppFavorite]
    ) -> [DAppViewModel]

    func createDAppsFromQuery(_ query: String?, dAppList: DAppList) -> [DAppViewModel]
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
        }.sorted { model1, model2 in
            let favorite1 = favorites[model1.dapp.identifier] != nil ? 1 : 0
            let favorite2 = favorites[model2.dapp.identifier] != nil ? 1 : 0

            if favorite1 > favorite2 {
                return true
            } else if favorite1 < favorite2 {
                return false
            } else {
                return model1.index < model2.index
            }
        }

        let categories = dAppList.categories.reduce(into: [String: DAppCategory]()) { result, category in
            result[category.identifier] = category
        }

        let knownViewModels: [DAppViewModel] = actualDApps.map { indexedDapp in
            let favorite = favorites[indexedDapp.dapp.identifier] != nil ? true : false
            return createDAppViewModel(
                from: indexedDapp.dapp,
                index: indexedDapp.index,
                categories: categories,
                favorite: favorite
            )
        }

        if category == nil {
            let knownIdentifiers = Set(dAppList.dApps.map(\.identifier))

            let favoriteViewModels = favorites.values.filter {
                !knownIdentifiers.contains($0.identifier)
            }.sorted { model1, model2 in
                model1.identifier.localizedCompare(model2.identifier) == .orderedAscending
            }.map { createFavoriteDAppViewModel(from: $0) }

            return favoriteViewModels + knownViewModels
        } else {
            return knownViewModels
        }
    }

    func createDAppsFromQuery(_ query: String?, dAppList: DAppList) -> [DAppViewModel] {
        let actualDApps: [(Int, DApp)] = dAppList.dApps.enumerated().compactMap { valueIndex in
            guard let query = query, !query.isEmpty else {
                return valueIndex
            }

            if valueIndex.element.name.localizedCaseInsensitiveContains(query) {
                return valueIndex
            } else {
                return nil
            }
        }

        let categories = dAppList.categories.reduce(into: [String: DAppCategory]()) { result, category in
            result[category.identifier] = category
        }

        // TODO: Apply favorites for search
        return actualDApps.map {
            createDAppViewModel(from: $0.1, index: $0.0, categories: categories, favorite: false)
        }
    }
}
