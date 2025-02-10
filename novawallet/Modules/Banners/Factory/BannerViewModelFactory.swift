import Foundation

protocol BannerViewModelFactoryProtocol {
    func createWidgetViewModel(
        for banners: [Banner]?,
        closedBannerIds: Set<String>?,
        closeAvailable: Bool,
        localizedResources: BannersLocalizedResources?
    ) -> BannersWidgetviewModel?

    func createLoadableWidgetViewModel(
        for banners: [Banner]?,
        closedBannerIds: Set<String>?,
        closeAvailable: Bool,
        localizedResources: BannersLocalizedResources?
    ) -> LoadableViewModelState<BannersWidgetviewModel>?
}

class BannerViewModelFactory {
    private func createBannerViewModels(
        for banners: [Banner],
        closedBannerIds: Set<String>?,
        localizedResources: BannersLocalizedResources
    ) -> [BannerViewModel] {
        banners
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
    }
}

extension BannerViewModelFactory: BannerViewModelFactoryProtocol {
    func createLoadableWidgetViewModel(
        for banners: [Banner]?,
        closedBannerIds: Set<String>?,
        closeAvailable: Bool,
        localizedResources: BannersLocalizedResources?
    ) -> LoadableViewModelState<BannersWidgetviewModel>? {
        guard let banners, let localizedResources else {
            return .loading
        }

        let bannerViewModels: [BannerViewModel] = createBannerViewModels(
            for: banners,
            closedBannerIds: closedBannerIds,
            localizedResources: localizedResources
        )

        guard !bannerViewModels.isEmpty else {
            return nil
        }

        let widgetViewModel = BannersWidgetviewModel(
            showsCloseButton: closeAvailable,
            banners: bannerViewModels
        )

        return .loaded(value: widgetViewModel)
    }

    func createWidgetViewModel(
        for banners: [Banner]?,
        closedBannerIds: Set<String>?,
        closeAvailable: Bool,
        localizedResources: BannersLocalizedResources?
    ) -> BannersWidgetviewModel? {
        guard let banners, let localizedResources else {
            return nil
        }

        let bannerViewModels: [BannerViewModel] = createBannerViewModels(
            for: banners,
            closedBannerIds: closedBannerIds,
            localizedResources: localizedResources
        )

        return BannersWidgetviewModel(
            showsCloseButton: closeAvailable,
            banners: bannerViewModels
        )
    }
}
