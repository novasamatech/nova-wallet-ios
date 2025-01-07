import Foundation

protocol DAppSearchingByQuery {
    func search(
        by query: String?,
        in dAppList: DAppList?
    ) -> [IndexedDApp]
}

extension DAppSearchingByQuery {
    func search(
        by query: String?,
        in dAppList: DAppList?
    ) -> [IndexedDApp] {
        guard let dAppList else { return [] }

        return dAppList.dApps.enumerated().compactMap { valueIndex in
            guard let query = query, !query.isEmpty else {
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
}
