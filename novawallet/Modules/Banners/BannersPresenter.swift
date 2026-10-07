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
    private var localBanners: [Banners.LocalBanner] = []
    private var availableTextWidth: CGFloat = .zero
    private var setUp: Bool = false

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
        let viewModel = viewModelFactory.createLoadableWidgetViewModel(
            for: allBanners,
            closedBanners: closedBanners,
            closeAvailable: closeActionAvailable,
            localizedResources: allLocalizedResources
        )

        view?.update(with: viewModel)
    }
}

// MARK: Private

private extension BannersPresenter {
    var visibleLocalBanners: [Banners.LocalBanner] {
        localBanners.filter { closedBanners?.contains($0.banner.id) != true }
    }

    var allBanners: [Banner]? {
        let localIds = Set(localBanners.map(\.banner.id))
        let remoteBanners = banners?.filter { !localIds.contains($0.id) }

        guard remoteBanners != nil || !visibleLocalBanners.isEmpty else {
            return nil
        }

        return visibleLocalBanners.map(\.banner) + (remoteBanners ?? [])
    }

    var allLocalizedResources: BannersLocalizedResources? {
        guard localizedResources != nil || !visibleLocalBanners.isEmpty else {
            return nil
        }

        let localResources = viewModelFactory.createLocalizedResources(
            for: visibleLocalBanners,
            availableTextWidth: availableTextWidth
        )

        return (localizedResources ?? [:]).merging(localResources) { _, local in local }
    }
}

// MARK: BannersPresenterProtocol

extension BannersPresenter: BannersPresenterProtocol {
    func setup(with availableTextWidth: CGFloat) {
        guard !setUp, availableTextWidth > 0 else { return }

        self.availableTextWidth = availableTextWidth

        provideBanners()

        interactor.setup(
            with: locale,
            availableTextWidth: availableTextWidth
        )
        setUp = true
    }

    func action(for bannerId: String) {
        if localBanners.contains(where: { $0.banner.id == bannerId }) {
            trackBannerClicked(with: bannerId)
            moduleOutput?.didSelectLocalBanner(with: bannerId)
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
        let oldMaxTextHeight = allLocalizedResources.map { viewModelFactory.maxTextHeight(for: $0) }

        closedBanners = updatedClosedBanners

        guard let viewModel = viewModelFactory.createWidgetViewModel(
            for: allBanners,
            closedBanners: closedBanners,
            closeAvailable: closeActionAvailable,
            localizedResources: allLocalizedResources
        ) else {
            provideBanners()
            moduleOutput?.didReceiveBanners(state: bannersState)
            return
        }

        guard !viewModel.banners.isEmpty else {
            moduleOutput?.didReceiveBanners(state: bannersState)
            return
        }

        view?.didCloseBanner(updatedViewModel: viewModel)

        if oldMaxTextHeight != viewModel.maxTextHeight {
            moduleOutput?.didUpdateContent(state: bannersState)
        }
    }

    func didLoad(closedBanners: ClosedBanners) {
        self.closedBanners = closedBanners

        guard !localBanners.isEmpty else { return }

        provideBanners()

        moduleOutput?.didReceiveBanners(state: bannersState)
    }

    func didReceive(_ error: any Error) {
        moduleOutput?.didReceive(error)
    }
}

// MARK: BannersModuleInputProtocol

extension BannersPresenter: BannersModuleInputProtocol {
    var bannersState: BannersState {
        guard let closedBanners else {
            return .loading
        }

        let hasVisibleBanners = (allBanners ?? []).contains { !closedBanners.contains($0.id) }

        if hasVisibleBanners {
            return .available
        }

        return banners == nil ? .loading : .unavailable
    }

    func refresh() {
        guard let availableTextWidth = view?.getAvailableTextWidth() else { return }

        self.availableTextWidth = availableTextWidth

        interactor.refresh(
            for: locale,
            availableTextWidth: availableTextWidth
        )
    }

    func updateLocale(_ newLocale: Locale) {
        guard let availableTextWidth = view?.getAvailableTextWidth() else { return }

        locale = newLocale
        self.availableTextWidth = availableTextWidth

        interactor.updateResources(
            for: newLocale,
            availableTextWidth: availableTextWidth
        )
    }

    func updateLocalBanners(_ banners: [Banners.LocalBanner]) {
        localBanners = banners

        provideBanners()

        moduleOutput?.didReceiveBanners(state: bannersState)
    }
}
