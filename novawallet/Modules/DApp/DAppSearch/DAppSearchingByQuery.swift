import Foundation

protocol DAppSearchingByQuery {
    func search(
        by query: String?,
        in dAppList: DAppList?
    ) -> [IndexedDApp]

    func search(
        by query: String?,
        in favorites: [String: DAppFavorite]
    ) -> [String: DAppFavorite]
}

extension DAppSearchingByQuery {
    func search(
        by query: String?,
        in dAppList: DAppList?
    ) -> [IndexedDApp] {
        guard let dAppList else { return [] }

        return dAppList.dApps.enumerated().compactMap { valueIndex in
            guard let query, !query.isEmpty else {
                return IndexedDApp(index: valueIndex.offset, dapp: valueIndex.element)
            }

            if valueIndex.element.name.localizedCaseInsensitiveContains(query) {
                return IndexedDApp(index: valueIndex.offset, dapp: valueIndex.element)
            } else if let queryURL = URL(string: query), valueIndex.element.url.host == queryURL.host {
                return IndexedDApp(index: valueIndex.offset, dapp: valueIndex.element)
            } else {
                return nil
            }
        }
    }

    func search(
        by query: String?,
        in favorites: [String: DAppFavorite]
    ) -> [String: DAppFavorite] {
        favorites.filter { dApp in
            guard let query, !query.isEmpty else {
                return true
            }

            if
                let name = dApp.value.label,
                name.localizedCaseInsensitiveContains(query) {
                return true
            } else if
                let queryURL = URL(string: query),
                let dAppURL = URL(string: dApp.value.identifier),
                dAppURL.host == queryURL.host {
                return true
            } else {
                return false
            }
        }
    }
}
