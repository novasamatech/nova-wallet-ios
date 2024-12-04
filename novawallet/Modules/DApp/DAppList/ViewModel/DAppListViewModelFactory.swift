import Foundation
import SubstrateSdk

protocol DAppListViewModelFactoryProtocol {
    func createFavoriteDAppName(from model: DAppFavorite) -> String

    func createFavoriteDApps(from list: [DAppFavorite]) -> [DAppViewModel]

    func createDApps(
        from category: String?,
        query: String?,
        dAppList: DAppList,
        favorites: [String: DAppFavorite]
    ) -> DAppListViewModel

    func createDAppSections(
        from dAppList: DAppList,
        favorites: [String: DAppFavorite],
        wallet: MetaAccountModel,
        hasWalletsListUpdates: Bool,
        locale: Locale
    ) -> [DAppListSection]
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

private typealias IndexedDApp = (index: Int, dapp: DApp)

final class DAppListViewModelFactory {
    private let dappCategoriesViewModelFactory: DAppCategoryViewModelFactoryProtocol
    private let walletSwitchViewModelFactory = WalletSwitchViewModelFactory()

    init(dappCategoriesViewModelFactory: DAppCategoryViewModelFactoryProtocol) {
        self.dappCategoriesViewModelFactory = dappCategoriesViewModelFactory
    }
}

// MARK: Private

private extension DAppListViewModelFactory {
    func createDAppViewModel(
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

    func createFavoriteDAppViewModel(from model: DAppFavorite) -> DAppViewModel {
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

    func createViewModels(
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

    // MARK: Sections

    func favoritesSection(
        from favorites: [String: DAppFavorite],
        locale: Locale
    ) -> DAppListSectionViewModel {
        let favoritesDApps = createFavoriteDApps(from: Array(favorites.values))

        return DAppListSectionViewModel(
            title: R.string.localizable.commonFavorites(preferredLanguages: locale.rLanguages),
            items: favoritesDApps.map { .favorites($0) }
        )
    }

    func categorySections(
        from dAppList: DAppList,
        favorites: [String: DAppFavorite]
    ) -> [DAppListSectionViewModel] {
        let categoriesById: [String: DAppCategory] = dAppList.categories
            .reduce(into: [:]) { $0[$1.identifier] = $1 }

        let dAppsByCategory: [String: [DApp]] = dAppList.dApps.reduce(into: [:]) { acc, dApp in
            dApp.categories.forEach { categoryId in
                acc[categoryId] = acc[categoryId] ?? [] + [dApp]
            }
        }

        let categorySections: [DAppListSectionViewModel] = dAppsByCategory.keys.compactMap { categoryId in
            guard
                let dApps = dAppsByCategory[categoryId],
                let category = categoriesById[categoryId]
            else { return nil }

            let indexedDApps: [IndexedDApp] = dApps.enumerated().compactMap { valueIndex in
                IndexedDApp(index: valueIndex.offset, dapp: valueIndex.element)
            }

            let dAppViewModels = createViewModels(
                merging: indexedDApps,
                filteredFavorites: [:],
                allFavorites: favorites,
                categories: [category]
            )

            return DAppListSectionViewModel(
                title: categoriesById[categoryId]?.name ?? categoryId,
                items: dAppViewModels.map { .category($0) }
            )
        }

        return categorySections
    }

    func categorySelectSection(from dAppList: DAppList) -> DAppListSectionViewModel {
        let categoryViewModels = dappCategoriesViewModelFactory.createViewModels(for: dAppList.categories)

        return DAppListSectionViewModel(
            title: nil,
            items: [.categorySelect(categoryViewModels)]
        )
    }

    func headerSection(
        for wallet: MetaAccountModel,
        hasWalletsListUpdates: Bool
    ) -> DAppListSectionViewModel {
        let headerViewModel = walletSwitchViewModelFactory.createViewModel(
            from: wallet.walletIdenticonData(),
            walletType: wallet.type,
            hasNotification: hasWalletsListUpdates
        )

        return DAppListSectionViewModel(
            title: nil,
            items: [.header(headerViewModel)]
        )
    }
}

// MARK: DAppListViewModelFactoryProtocol

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
        query: String?,
        dAppList: DAppList,
        favorites: [String: DAppFavorite]
    ) -> DAppListViewModel {
        let dAppsByQuery: [IndexedDApp] = dAppList.dApps.enumerated().compactMap { valueIndex in
            guard let query = query, !query.isEmpty else {
                return IndexedDApp(index: valueIndex.offset, dapp: valueIndex.element)
            }

            if valueIndex.element.name.localizedCaseInsensitiveContains(query) {
                return IndexedDApp(index: valueIndex.offset, dapp: valueIndex.element)
            } else {
                return nil
            }
        }

        let actualDApps: [IndexedDApp] = dAppsByQuery.filter { indexedDApp in
            guard let category else { return true }

            return indexedDApp.dapp.categories.contains(category)
        }

        let filteredFavorites = favorites.filter { keyValue in
            guard let query = query, !query.isEmpty else {
                return true
            }

            let name = createFavoriteDAppName(from: keyValue.value)
            return name.localizedCaseInsensitiveContains(query)
        }

        let availableCategories = Set(dAppsByQuery.flatMap(\.dapp.categories))

        let categoryViewModels = dAppList.categories
            .filter { availableCategories.contains($0.identifier) }
            .map { dappCategoriesViewModelFactory.createViewModel(for: $0) }

        let dappViewModels = createViewModels(
            merging: actualDApps,
            filteredFavorites: filteredFavorites,
            allFavorites: favorites,
            categories: dAppList.categories
        )

        return DAppListViewModel(
            categories: categoryViewModels,
            dApps: dappViewModels
        )
    }

    func createDAppSections(
        from dAppList: DAppList,
        favorites: [String: DAppFavorite],
        wallet: MetaAccountModel,
        hasWalletsListUpdates: Bool,
        locale: Locale
    ) -> [DAppListSection] {
        let favoritesSection = favoritesSection(
            from: favorites,
            locale: locale
        )
        let categorySections = categorySections(
            from: dAppList,
            favorites: favorites
        )

        let categorySelectSection = categorySelectSection(from: dAppList)

        let headerSection = headerSection(
            for: wallet,
            hasWalletsListUpdates: hasWalletsListUpdates
        )

        return [
            .header(headerSection),
            .categorySelect(categorySelectSection),
            .favorites(favoritesSection)
        ]
            + categorySections.map { .category($0) }
    }
}
