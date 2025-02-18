import Foundation
import SoraFoundation

final class BannersPresenter {
    weak var view: BannersViewProtocol?
    weak var moduleOutput: BannersModuleOutputProtocol?

    private let wireframe: BannersWireframeProtocol
    private let interactor: BannersInteractorInputProtocol
    private let viewModelFactory: BannerViewModelFactoryProtocol
    private var locale: Locale

    private let closeActionAvailable: Bool

    private var banners: [Banner]?
    private var closedBanners: ClosedBanners?
    private var localizedResources: BannersLocalizedResources?

    init(
        interactor: BannersInteractorInputProtocol,
        wireframe: BannersWireframeProtocol,
        viewModelFactory: BannerViewModelFactoryProtocol,
        locale: Locale,
        closeActionAvailable: Bool
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.locale = locale
        self.closeActionAvailable = closeActionAvailable
    }

    private func provideBanners() {
        let viewModel = viewModelFactory.createLoadableWidgetViewModel(
            for: banners,
            closedBanners: closedBanners,
            closeAvailable: closeActionAvailable,
            localizedResources: localizedResources
        )

        view?.update(with: viewModel)
    }
}

// MARK: BannersPresenterProtocol

extension BannersPresenter: BannersPresenterProtocol {
    func setup() {
        provideBanners()
        interactor.setup(with: locale)
    }

    func action(for bannerId: String) {
        guard
            let banner = banners?.first(where: { $0.id == bannerId }),
            let actionLink = banner.actionLink
        else {
            return
        }

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

        guard let viewModel = viewModelFactory.createWidgetViewModel(
            for: banners,
            closedBanners: closedBanners,
            closeAvailable: closeActionAvailable,
            localizedResources: localizedResources
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
        moduleOutput?.didReceive(error)
    }
}

// MARK: BannersModuleInputProtocol

extension BannersPresenter: BannersModuleInputProtocol {
    var bannersState: BannersState {
        guard let banners, let closedBanners else {
            return .loading
        }

        return banners
            .filter { !closedBanners.contains($0.id) }
            .isEmpty
            ? .unavailable
            : .available
    }

    func refresh() {
        interactor.refresh(for: locale)
    }

    func updateLocale(_ newLocale: Locale) {
        locale = newLocale

        interactor.updateResources(for: newLocale)
    }
}
