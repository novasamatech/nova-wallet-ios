import Foundation
import SubstrateSdk

typealias IndexedDApp = (index: Int, dapp: DApp)

final class DAppListViewModelFactory: DAppSearchingByQuery {
    private let dappCategoriesViewModelFactory: DAppCategoryViewModelFactoryProtocol
    private let walletSwitchViewModelFactory = WalletSwitchViewModelFactory()
    private let dappIconViewModelFactory: DAppIconViewModelFactoryProtocol

    init(
        dappCategoriesViewModelFactory: DAppCategoryViewModelFactoryProtocol,
        dappIconViewModelFactory: DAppIconViewModelFactoryProtocol
    ) {
        self.dappCategoriesViewModelFactory = dappCategoriesViewModelFactory
        self.dappIconViewModelFactory = dappIconViewModelFactory
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
        let imageViewModel = dappIconViewModelFactory.createIconViewModel(for: model)

        let details = model.categories.compactMap {
            categories[$0]?.name
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
        categories: [String: DAppCategory],
        showsFavoriteIcons: Bool
    ) -> [DAppViewModel] {
        let viewModels = list
            .sorted { $0.index ?? 0 < $1.index ?? 0 }
            .map {
                createFavoriteDAppViewModel(
                    from: $0,
                    knownDApps: knownDApps,
                    categoriesDict: categories,
                    showsFavoriteIcon: showsFavoriteIcons
                )
            }

        return viewModels
    }

    func createFavoriteDAppViewModel(
        from model: DAppFavorite,
        knownDApps: [String: DApp],
        categoriesDict: [String: DAppCategory],
        showsFavoriteIcon: Bool
    ) -> DAppViewModel {
        let imageViewModel = dappIconViewModelFactory.createIconViewModel(for: model)
        let name = createFavoriteDAppName(from: model)

        let details = if let knownDApp = knownDApps[model.identifier] {
            knownDApp.categories.map {
                categoriesDict[$0]?.name ?? $0
            }.joined(separator: ", ")
        } else {
            model.identifier
        }

        return DAppViewModel(
            identifier: model.identifier,
            name: name,
            details: details,
            icon: imageViewModel,
            isFavorite: showsFavoriteIcon,
            order: model.index
        )
    }

    func createViewModels(
        merging dapps: [IndexedDApp],
        allFavorites: [String: DAppFavorite],
        categoriesDict: [String: DAppCategory]
    ) -> [DAppViewModel] {
        let viewModels: [DAppViewModel] = dapps.map { indexedDapp in
            let favorite = allFavorites[indexedDapp.dapp.identifier] != nil
            return createDAppViewModel(
                from: indexedDapp.dapp,
                index: indexedDapp.index,
                categories: categoriesDict,
                favorite: favorite
            )
        }

        let sortedViewModels = sortedDAppViewModels(from: viewModels)

        return sortedViewModels
    }

    func sortedDAppViewModels(from viewModels: [DAppViewModel]) -> [DAppViewModel] {
        viewModels.sorted { lhsModel, rhsModel in
            let lhsIsFavorite = lhsModel.isFavorite ? 1 : 0
            let rhsIsFavorite = rhsModel.isFavorite ? 1 : 0

            return if let lhsOrder = lhsModel.order, let rhsOrder = rhsModel.order {
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

        let name = R.string(preferredLanguages: locale.rLanguages).localizable.commonFavorites()

        return DAppListSection(
            title: name,
            cells: favoritesDApps.map { .favorites(model: $0, categoryName: name) }
        )
    }

    func popularSection(
        from dAppList: DAppList,
        favorites: [String: DAppFavorite],
        locale: Locale
    ) -> DAppListSection? {
        guard
            !dAppList.popular.isEmpty,
            !dAppList.dApps.isEmpty
        else { return nil }

        let dappsById: [String: DApp] = dAppList.dApps.reduce(into: [:]) { $0[$1.identifier] = $1 }
        let popularDApps = dAppList.popular.compactMap { dappsById[$0.url.absoluteString] }

        let categoriesById: [String: DAppCategory] = dAppList.categories
            .reduce(into: [:]) { $0[$1.identifier] = $1 }

        let categoryName = R.string(preferredLanguages: locale.rLanguages).localizable.dappListSectionPopular()

        return createCategorySection(
            categoryName: categoryName,
            dApps: popularDApps,
            allCaregories: categoriesById,
            favorites: favorites
        )
    }

    func categorySections(
        from dAppList: DAppList,
        favorites: [String: DAppFavorite],
        randomizationSeed: Int
    ) -> [DAppListSection]? {
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

        let categoriesById: [String: DAppCategory] = dAppList.categories
            .reduce(into: [:]) { $0[$1.identifier] = $1 }

        let categorySections: [DAppListSection] = dAppList.categories.compactMap { category in
            guard let dApps = dAppsByCategory[category.identifier] else { return nil }

            var dAppsById: [String: DApp] = dApps.reduce(into: [:]) { $0[$1.identifier] = $1 }

            let popular: [DApp] = dAppList.popular.compactMap { dAppsById[$0.url.absoluteString] }

            popular.forEach {
                dAppsById[$0.identifier] = nil
            }

            let filteredDApps: [DApp] = dApps.compactMap { dAppsById[$0.url.absoluteString] }

            let finalDApps = shuffled(
                popular,
                with: randomizationSeed
            ) + shuffled(
                filteredDApps,
                with: randomizationSeed
            )

            return createCategorySection(
                categoryName: category.name,
                dApps: finalDApps,
                allCaregories: categoriesById,
                favorites: favorites
            )
        }

        return categorySections
    }

    func shuffled(
        _ dApps: [DApp],
        with seed: Int
    ) -> [DApp] {
        var randomGenerator = SplitMix64Generator(seed: seed)

        return dApps.shuffled(using: &randomGenerator)
    }

    func createCategorySection(
        categoryName: String,
        dApps: [DApp],
        allCaregories: [String: DAppCategory],
        favorites: [String: DAppFavorite]
    ) -> DAppListSection? {
        guard !dApps.isEmpty else {
            return nil
        }

        let indexedDApps: [IndexedDApp] = dApps.enumerated().compactMap { valueIndex in
            IndexedDApp(index: valueIndex.offset, dapp: valueIndex.element)
        }

        let dAppViewModels = createViewModels(
            merging: indexedDApps,
            allFavorites: favorites,
            categoriesDict: allCaregories
        )

        return DAppListSection(
            title: categoryName,
            cells: dAppViewModels.map { .category(model: $0, categoryName: categoryName) }
        )
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
            from: wallet.identifier,
            walletIdenticon: wallet.walletIdenticonData(),
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
            categories: categories,
            showsFavoriteIcons: false
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

        let knownDApps: [String: DApp] = actualDApps.reduce(into: [:]) { acc, indexedDApp in
            acc[indexedDApp.dapp.identifier] = indexedDApp.dapp
        }

        let actualFavorites = if let category {
            favoritesByQuery.filter {
                guard let knownDApp = knownDApps[$0.value.identifier] else {
                    return false
                }

                return knownDApp.categories.contains(category)
            }
        } else {
            favoritesByQuery
        }

        let favoritesViewModels = createFavorites(
            from: Array(actualFavorites.values),
            knownDApps: knownDApps,
            categories: categoriesById,
            showsFavoriteIcons: true
        )

        let dappViewModels = createViewModels(
            merging: actualDApps,
            allFavorites: favorites,
            categoriesDict: categoriesById
        ).filter { favoritesByQuery[$0.identifier] == nil }

        let selectedCategoryIndex = categoryViewModels.firstIndex(where: { $0.identifier == category })

        return DAppListViewModel(
            selectedCategoryIndex: selectedCategoryIndex,
            categories: categoryViewModels,
            dApps: favoritesViewModels + dappViewModels
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
        wallet: MetaAccountModel?,
        params: DAppListViewModelFactory.ListSectionsParams,
        bannersState: BannersState,
        locale: Locale
    ) -> [DAppListSectionViewModel] {
        var viewModels: [DAppListSectionViewModel] = []

        if let wallet {
            let headerSection = headerSection(
                for: wallet,
                hasWalletsListUpdates: params.hasWalletsListUpdates
            )
            viewModels.append(.header(headerSection))
        }

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

        if bannersState == .available || bannersState == .loading {
            let bannersSection = DAppListSection(
                title: nil,
                cells: [.banner]
            )
            viewModels.append(.banners(bannersSection))
        }

        if let favoritesSection = favoritesSection(
            from: favorites,
            dAppList: dAppList,
            locale: locale
        ) {
            viewModels.append(.favorites(favoritesSection))
        }

        if let popularSection = popularSection(
            from: dAppList,
            favorites: favorites,
            locale: locale
        ) {
            viewModels.append(.category(popularSection))
        }

        if let categorySections = categorySections(
            from: dAppList,
            favorites: favorites,
            randomizationSeed: params.randomizationSeed
        ) {
            viewModels.append(contentsOf: categorySections.map { .category($0) })
        }

        return viewModels
    }
}

extension DAppListViewModelFactory {
    struct ListSectionsParams {
        let randomizationSeed: Int
        let hasWalletsListUpdates: Bool
    }
}
