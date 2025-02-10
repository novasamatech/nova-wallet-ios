import Foundation

protocol BannerViewModelFactoryProtocol {
    func createBannerViewModels(
        for banners: [Banner]?,
        closedBannerIds: Set<String>?,
        localizedResources: BannersLocalizedResources?
    ) -> LoadableViewModelState<[BannerViewModel]>?
}

class BannerViewModelFactory: BannerViewModelFactoryProtocol {
    func createBannerViewModels(
        for banners: [Banner]?,
        closedBannerIds: Set<String>?,
        localizedResources: BannersLocalizedResources?
    ) -> LoadableViewModelState<[BannerViewModel]>? {
        guard let banners, let localizedResources else {
            return .loading
        }

        let viewModels: [BannerViewModel] = banners
            .filter { closedBannerIds?.contains($0.id) != true }
            .compactMap { banner in
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

        return viewModels.isEmpty ? nil : .loaded(value: viewModels)
    }
}
