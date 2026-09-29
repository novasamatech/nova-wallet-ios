import Foundation
import Foundation_iOS

final class BannersPresenter {
    weak var view: BannersViewProtocol?
    weak var moduleOutput: BannersModuleOutputProtocol?
    var locale: Locale

    private let wireframe: BannersWireframeProtocol
    private let interactor: BannersInteractorInputProtocol
    private let viewModelFactory: BannerViewModelFactoryProtocol
    let domain: Banners.Domain

    private let closeActionAvailable: Bool

    private var banners: [Banner]?
    private var closedBanners: ClosedBanners?
    private var localizedResources: BannersLocalizedResources?
    private var bittensorContent: BittensorLocalBannerContent?
    private var setUp: Bool = false

    private var resolvedContent: (banners: [Banner], closed: ClosedBanners, resources: BannersLocalizedResources)? {
        guard let bittensorContent else {
            guard let banners, let closedBanners, let localizedResources else {
                return nil
            }

            return (banners, closedBanners, localizedResources)
        }

        var resources = localizedResources ?? [:]
        resources[BittensorLocalBanner.id] = bittensorContent.resource

        return (
            [bittensorContent.banner] + (banners ?? []),
            closedBanners ?? ClosedBanners(),
            resources
        )
    }

    private var showsBittensorBanner: Bool {
        guard bittensorContent != nil else {
            return false
        }

        return !(closedBanners?.contains(BittensorLocalBanner.id) ?? false)
    }

    init(
        interactor: BannersInteractorInputProtocol,
        wireframe: BannersWireframeProtocol,
        viewModelFactory: BannerViewModelFactoryProtocol,
        domain: Banners.Domain,
        locale: Locale,
        closeActionAvailable: Bool
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.domain = domain
        self.locale = locale
        self.closeActionAvailable = closeActionAvailable
    }

    private func provideBanners() {
        let content = resolvedContent
        let viewModel = viewModelFactory.createLoadableWidgetViewModel(
            for: content?.banners,
            closedBanners: content?.closed,
            closeAvailable: closeActionAvailable,
            localizedResources: content?.resources
        )

        view?.update(with: viewModel)
    }

    private func openBittensorBanner() {
        guard let model = bittensorContent?.model else {
            return
        }

        switch model.variant {
        case .earn:
            wireframe.showBittensorEarn(from: view, chainAsset: model.chainAsset)
        case .getTao:
            wireframe.showBittensorGetTao(from: view, chainAsset: model.chainAsset)
        }
    }
}

// MARK: BannersPresenterProtocol

extension BannersPresenter: BannersPresenterProtocol {
    func setup(with availableTextWidth: CGFloat) {
        guard !setUp, availableTextWidth > 0 else { return }

        provideBanners()

        interactor.setup(
            with: locale,
            availableTextWidth: availableTextWidth
        )
        setUp = true
    }

    func action(for bannerId: String) {
        if bannerId == BittensorLocalBanner.id {
            openBittensorBanner()
            return
        }

        guard
            let banner = banners?.first(where: { $0.id == bannerId }),
            let actionLink = banner.actionLink
        else {
            return
        }

        trackBannerClicked(with: banner.id)

        wireframe.openActionLink(urlString: actionLink)
    }

    func closeBanner(with id: String) {
        interactor.closeBanner(with: id)
    }
}

// MARK: BannersInteractorOutputProtocol

extension BannersPresenter: BannersInteractorOutputProtocol {
    func didReceive(_ bannersFetchResult: BannersFetchResult) {
        banners = bannersFetchResult.banners
        closedBanners = bannersFetchResult.closedBanners
        localizedResources = bannersFetchResult.localizedResources

        provideBanners()

        moduleOutput?.didReceiveBanners(state: bannersState)
    }

    func didReceive(_ updatedLocalizedResources: BannersLocalizedResources?) {
        localizedResources = updatedLocalizedResources
        provideBanners()

        moduleOutput?.didUpdateContent(state: bannersState)
    }

    func didReceive(_ updatedClosedBanners: ClosedBanners) {
        closedBanners = updatedClosedBanners

        let content = resolvedContent

        guard let viewModel = viewModelFactory.createWidgetViewModel(
            for: content?.banners,
            closedBanners: content?.closed,
            closeAvailable: closeActionAvailable,
            localizedResources: content?.resources
        ) else {
            return
        }

        guard !viewModel.banners.isEmpty else {
            moduleOutput?.didReceiveBanners(state: bannersState)
            return
        }

        view?.didCloseBanner(updatedViewModel: viewModel)
    }

    func didReceive(_ error: any Error) {
        guard showsBittensorBanner else {
            moduleOutput?.didReceive(error)
            return
        }

        moduleOutput?.didReceiveBanners(state: bannersState)
    }

    func didReceive(bittensorContent: BittensorLocalBannerContent?) {
        self.bittensorContent = bittensorContent

        provideBanners()

        moduleOutput?.didReceiveBanners(state: bannersState)
    }
}

// MARK: BannersModuleInputProtocol

extension BannersPresenter: BannersModuleInputProtocol {
    var bannersState: BannersState {
        guard let content = resolvedContent else {
            return .loading
        }

        return content.banners
            .filter { !content.closed.contains($0.id) }
            .isEmpty
            ? .unavailable
            : .available
    }

    func refresh() {
        guard let availableTextWidth = view?.getAvailableTextWidth() else { return }

        interactor.refresh(
            for: locale,
            availableTextWidth: availableTextWidth
        )
    }

    func updateLocale(_ newLocale: Locale) {
        guard let availableTextWidth = view?.getAvailableTextWidth() else { return }

        locale = newLocale

        interactor.updateResources(
            for: newLocale,
            availableTextWidth: availableTextWidth
        )
    }
}
