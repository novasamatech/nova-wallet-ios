import Foundation

protocol BannerViewModelFactoryProtocol {
    func createWidgetViewModel(
        for banners: [Banner]?,
        closedBanners: ClosedBanners?,
        closeAvailable: Bool,
        localizedResources: BannersLocalizedResources?
    ) -> BannersWidgetViewModel?

    func createLoadableWidgetViewModel(
        for banners: [Banner]?,
        closedBanners: ClosedBanners?,
        closeAvailable: Bool,
        localizedResources: BannersLocalizedResources?
    ) -> LoadableViewModelState<BannersWidgetViewModel>?

    func maxTextHeight(for localizedResources: BannersLocalizedResources) -> CGFloat
}

class BannerViewModelFactory {
    private func createBannerViewModels(
        for banners: [Banner],
        closedBanners: ClosedBanners,
        localizedResources: BannersLocalizedResources
    ) -> [BannerViewModel] {
        banners
            .filter { !closedBanners.contains($0.id) }
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
        closedBanners: ClosedBanners?,
        closeAvailable: Bool,
        localizedResources: BannersLocalizedResources?
    ) -> LoadableViewModelState<BannersWidgetViewModel>? {
        guard
            let banners,
            let localizedResources,
            let closedBanners
        else {
            return .loading
        }

        let bannerViewModels: [BannerViewModel] = createBannerViewModels(
            for: banners,
            closedBanners: closedBanners,
            localizedResources: localizedResources
        )

        guard !bannerViewModels.isEmpty else {
            return nil
        }

        let maxTextHeight = maxTextHeight(for: localizedResources)

        let widgetViewModel = BannersWidgetViewModel(
            showsCloseButton: closeAvailable,
            banners: bannerViewModels,
            maxTextHeight: maxTextHeight
        )

        return .loaded(value: widgetViewModel)
    }

    func createWidgetViewModel(
        for banners: [Banner]?,
        closedBanners: ClosedBanners?,
        closeAvailable: Bool,
        localizedResources: BannersLocalizedResources?
    ) -> BannersWidgetViewModel? {
        guard
            let banners,
            let localizedResources,
            let closedBanners
        else {
            return nil
        }

        let bannerViewModels: [BannerViewModel] = createBannerViewModels(
            for: banners,
            closedBanners: closedBanners,
            localizedResources: localizedResources
        )

        let maxTextHeight = maxTextHeight(for: localizedResources)

        return BannersWidgetViewModel(
            showsCloseButton: closeAvailable,
            banners: bannerViewModels,
            maxTextHeight: maxTextHeight
        )
    }

    func maxTextHeight(for localizedResources: BannersLocalizedResources) -> CGFloat {
        CGFloat(localizedResources.map(\.value.estimatedHeight).max() ?? 0)
    }
}
