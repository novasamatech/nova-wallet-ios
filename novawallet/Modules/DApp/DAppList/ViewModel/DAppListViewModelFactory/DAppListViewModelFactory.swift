import Foundation
import SubstrateSdk

typealias IndexedDApp = (index: Int, dapp: DApp)

final class DAppListViewModelFactory: DAppSearchingByQuery {
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
            identifier: model.identifier,
            name: model.name,
            details: details,
            icon: imageViewModel,
            isFavorite: favorite,
            order: index
        )
    }

    func createFavorites(
        from list: [DAppFavorite],
        knownDApps: [String: DApp],
        categories: [String: DAppCategory]
    ) -> [DAppViewModel] {
        let viewModels = list.map {
            createFavoriteDAppViewModel(
                from: $0,
                knownDApps: knownDApps,
                categoriesDict: categories
            )
        }

        return sortedDAppViewModels(from: viewModels)
    }

    func createFavoriteDAppViewModel(
        from model: DAppFavorite,
        knownDApps: [String: DApp],
        categoriesDict: [String: DAppCategory]
    ) -> DAppViewModel {
        let imageViewModel: ImageViewModelProtocol

        if let icon = model.icon, let url = URL(string: icon) {
            imageViewModel = RemoteImageViewModel(url: url)
        } else {
            imageViewModel = StaticImageViewModel(image: R.image.iconDefaultDapp()!)
        }

        let name = createFavoriteDAppName(from: model)

        let details = if let knownDApp = knownDApps[model.identifier] {
            knownDApp.categories.map {
                categoriesDict[$0]?.name ?? $0
            }.joined(separator: ", ") ?? knownDApp.identifier
        } else {
            model.identifier
        }

        return DAppViewModel(
            identifier: model.identifier,
            name: name,
            details: details,
            icon: imageViewModel,
            isFavorite: true,
            order: model.index
        )
    }

    func createViewModels(
        merging dapps: [IndexedDApp],
        filteredFavorites: [String: DAppFavorite],
        allFavorites: [String: DAppFavorite],
        categoriesDict: [String: DAppCategory],
        selectedCategory: String? = nil
    ) -> [DAppViewModel] {
        let knownDApps: [String: DApp] = dapps.reduce(into: [:]) { acc, indexedDApp in
            acc[indexedDApp.dapp.identifier] = indexedDApp.dapp
        }

        let knownViewModels: [DAppViewModel] = dapps.map { indexedDapp in
            let favorite = allFavorites[indexedDapp.dapp.identifier] != nil
            return createDAppViewModel(
                from: indexedDapp.dapp,
                index: indexedDapp.index,
                categories: categoriesDict,
                favorite: favorite
            )
        }

        let favoritePages: [DAppFavorite]

        if selectedCategory == nil {
            favoritePages = filteredFavorites.values.filter {
                knownDApps[$0.identifier] == nil
            }
        } else {
            favoritePages = []
        }

        let sortedKnownViewModels = sortedDAppViewModels(from: knownViewModels)

        let sortedFavoriteViewModels = createFavorites(
            from: favoritePages,
            knownDApps: knownDApps,
            categories: categoriesDict
        )

        return sortedFavoriteViewModels + sortedKnownViewModels
    }

    func sortedDAppViewModels(from viewModels: [DAppViewModel]) -> [DAppViewModel] {
        viewModels.sorted { lhsModel, rhsModel in
            let lhsIsFavorite = lhsModel.isFavorite ? 1 : 0
            let rhsIsFavorite = rhsModel.isFavorite ? 1 : 0

            return if lhsIsFavorite != rhsIsFavorite {
                lhsIsFavorite > rhsIsFavorite
            } else if let lhsOrder = lhsModel.order, let rhsOrder = rhsModel.order {
                lhsOrder < rhsOrder
            } else if lhsModel.order != nil {
                false
            } else if rhsModel.order != nil {
                true
            } else {
                lhsModel.name.localizedCompare(rhsModel.name) == .orderedAscending
            }
        }
    }

    // MARK: Sections

    func favoritesSection(
        from favorites: [String: DAppFavorite],
        dAppList: DAppList,
        locale: Locale
    ) -> DAppListSection? {
        guard !favorites.isEmpty else { return nil }

        let favoritesDApps = createFavoriteDApps(
            from: Array(favorites.values),
            dAppList: dAppList
        )

        let name = R.string.localizable.commonFavorites(preferredLanguages: locale.rLanguages)

        return DAppListSection(
            title: name,
            cells: favoritesDApps.map { .favorites(model: $0, categoryName: name) }
        )
    }

    func categorySections(from dAppList: DAppList) -> [DAppListSection]? {
        guard !dAppList.dApps.isEmpty else { return nil }

        let dAppsByCategory: [String: [DApp]] = dAppList.dApps.reduce(into: [:]) { acc, dApp in
            dApp.categories.forEach { categoryId in
                if acc[categoryId] != nil {
                    acc[categoryId]?.append(dApp)
                } else {
                    acc[categoryId] = [dApp]
                }
            }
        }

        let categorySections: [DAppListSection] = dAppList.categories.compactMap { category in
            guard let dApps = dAppsByCategory[category.identifier] else { return nil }

            let indexedDApps: [IndexedDApp] = dApps.enumerated().compactMap { valueIndex in
                IndexedDApp(index: valueIndex.offset, dapp: valueIndex.element)
            }

            let dAppViewModels = createViewModels(
                merging: indexedDApps,
                filteredFavorites: [:],
                allFavorites: [:],
                categoriesDict: [category.identifier: category]
            )

            return DAppListSection(
                title: category.name,
                cells: dAppViewModels.map { .category(model: $0, categoryName: category.name) }
            )
        }

        return categorySections
    }

    func categorySelectSection(from dAppList: DAppList) -> DAppListSection? {
        guard !dAppList.categories.isEmpty else { return nil }

        let categoryViewModels = dappCategoriesViewModelFactory.createViewModels(for: dAppList.categories)

        return DAppListSection(
            title: nil,
            cells: [.categorySelect(categoryViewModels)]
        )
    }

    func headerSection(
        for wallet: MetaAccountModel,
        hasWalletsListUpdates: Bool
    ) -> DAppListSection {
        let headerViewModel = walletSwitchViewModelFactory.createViewModel(
            from: wallet.walletIdenticonData(),
            walletType: wallet.type,
            hasNotification: hasWalletsListUpdates
        )

        return DAppListSection(
            title: nil,
            cells: [.header(headerViewModel)]
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

    func createFavoriteDApps(
        from list: [DAppFavorite],
        dAppList: DAppList
    ) -> [DAppViewModel] {
        let categories: [String: DAppCategory] = dAppList.categories.reduce(into: [:]) { acc, category in
            acc[category.identifier] = category
        }

        let knownDApps: [String: DApp] = dAppList.dApps.reduce(into: [:]) { acc, dApp in
            acc[dApp.identifier] = dApp
        }

        return createFavorites(
            from: list,
            knownDApps: knownDApps,
            categories: categories
        )
    }

    func createDApps(
        from category: String?,
        query: String?,
        dAppList: DAppList,
        favorites: [String: DAppFavorite]
    ) -> DAppListViewModel {
        let dAppsByQuery: [IndexedDApp] = search(by: query, in: dAppList)
        let actualDApps: [IndexedDApp] = dAppsByQuery.filter { indexedDApp in
            guard let category else { return true }

            return indexedDApp.dapp.categories.contains(category)
        }

        let favoritesByQuery = search(by: query, in: favorites)

        let categoryViewModels = dAppList.categories
            .map { dappCategoriesViewModelFactory.createViewModel(for: $0) }

        let categoriesById = dAppList.categories.reduce(into: [String: DAppCategory]()) { result, category in
            result[category.identifier] = category
        }

        let dappViewModels = createViewModels(
            merging: actualDApps,
            filteredFavorites: favoritesByQuery,
            allFavorites: favorites,
            categoriesDict: categoriesById,
            selectedCategory: category
        )

        let selectedCategoryIndex = categoryViewModels.firstIndex(where: { $0.identifier == category })

        return DAppListViewModel(
            selectedCategoryIndex: selectedCategoryIndex,
            categories: categoryViewModels,
            dApps: dappViewModels
        )
    }

    func createErrorSection() -> DAppListSectionViewModel {
        .error(
            DAppListSection(
                title: nil,
                cells: [.error]
            )
        )
    }

    func createDAppSections(
        from dAppList: DAppList?,
        favorites: [String: DAppFavorite],
        wallet: MetaAccountModel,
        hasWalletsListUpdates: Bool,
        locale: Locale
    ) -> [DAppListSectionViewModel] {
        var viewModels: [DAppListSectionViewModel] = []

        let headerSection = headerSection(
            for: wallet,
            hasWalletsListUpdates: hasWalletsListUpdates
        )
        viewModels.append(.header(headerSection))

        guard let dAppList else {
            viewModels.append(
                .notLoaded(
                    DAppListSection(
                        title: nil,
                        cells: [.notLoaded]
                    )
                )
            )
            return viewModels
        }

        if let categorySelectSection = categorySelectSection(from: dAppList) {
            viewModels.append(.categorySelect(categorySelectSection))
        }

        if let favoritesSection = favoritesSection(
            from: favorites,
            dAppList: dAppList,
            locale: locale
        ) {
            viewModels.append(.favorites(favoritesSection))
        }

        if let categorySections = categorySections(from: dAppList) {
            viewModels.append(contentsOf: categorySections.map { .category($0) })
        }

        return viewModels
    }
}
