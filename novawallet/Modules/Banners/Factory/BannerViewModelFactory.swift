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

        let viewModels: [BannerViewModel] = banners.compactMap { banner in
            guard let localizedContent = localizedResources[banner.id] else {
                return nil
            }

            let backgroundImageViewModel = RemoteImageViewModel(url: banner.background)
            let contentImageViewModel = RemoteImageViewModel(url: banner.image)

            return BannerViewModel(
                id: banner.id,
                title: localizedContent.title,
                details: localizedContent.details,
                backgroundImage: backgroundImageViewModel,
                contentImage: contentImageViewModel,
                clipsToBounds: banner.clipsToBounds
            )
        }

        return viewModels.isEmpty ? nil : .loaded(value: viewModels)
    }
}
