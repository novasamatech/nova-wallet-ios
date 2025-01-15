import Foundation

protocol DAppCategoryViewModelFactoryProtocol {
    func createViewModels(for categories: [DAppCategory]) -> [DAppCategoryViewModel]
    func createViewModel(for category: DAppCategory) -> DAppCategoryViewModel
}

struct DAppCategoryViewModelFactory: DAppCategoryViewModelFactoryProtocol {
    func createViewModels(for categories: [DAppCategory]) -> [DAppCategoryViewModel] {
        categories.map { createViewModel(for: $0) }
    }

    func createViewModel(for category: DAppCategory) -> DAppCategoryViewModel {
        let imageViewModel: ImageViewModelProtocol? = {
            guard let url = category.icon else { return nil }

            return RemoteImageViewModel(url: url)
        }()

        return DAppCategoryViewModel(
            identifier: category.identifier,
            title: category.name,
            imageViewModel: imageViewModel
        )
    }
}
