import Foundation

protocol DAppListViewModelFactoryProtocol {
    func createDApps(from category: String?, dAppList: DAppList) -> [DAppViewModel]
}

final class DAppListViewModelFactory {
    private func createDAppViewModel(
        from model: DApp,
        index: Int,
        categories: [String: DAppCategory]
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

        return DAppViewModel(index: index, name: model.name, details: details, icon: imageViewModel)
    }
}

extension DAppListViewModelFactory: DAppListViewModelFactoryProtocol {
    func createDApps(from category: String?, dAppList: DAppList) -> [DAppViewModel] {
        let actualDApps: [(Int, DApp)] = dAppList.dApps.enumerated().compactMap { valueIndex in
            if let category = category {
                return valueIndex.element.categories.contains(category) ? valueIndex : nil
            } else {
                return valueIndex
            }
        }

        let categories = dAppList.categories.reduce(into: [String: DAppCategory]()) { result, category in
            result[category.identifier] = category
        }

        return actualDApps.map { createDAppViewModel(from: $0.1, index: $0.0, categories: categories) }
    }
}
