import Foundation

protocol BannerViewModelFactoryProtocol {
    func createBannerViewModels(
        for banners: [Banner]?,
        localizedResources: BannersLocalizedResources?
    ) -> LoadableViewModelState<[BannerViewModel]>?
}

class BannerViewModelFactory: BannerViewModelFactoryProtocol {
    func createBannerViewModels(
        for banners: [Banner]?,
        localizedResources: BannersLocalizedResources?
    ) -> LoadableViewModelState<[BannerViewModel]>? {
        guard let banners, let localizedResources else {
            return .loading
        }

        var viewModels: [BannerViewModel] = banners.compactMap { banner in
            guard let localizedContent = localizedResources[banner.id] else {
                return nil
            }

            return BannerViewModel(
                id: banner.id,
                title: localizedContent.title,
                details: localizedContent.details,
                backgroundImage: banner.background,
                contentImage: banner.image,
                clipsToBounds: banner.clipsToBounds
            )
        }

        if !viewModels.isEmpty {
            viewModels.append(viewModels.first!)
        }

        return viewModels.isEmpty ? nil : .loaded(value: viewModels)
    }
}
