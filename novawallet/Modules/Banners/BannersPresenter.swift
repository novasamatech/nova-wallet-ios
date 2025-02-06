import Foundation
import SoraFoundation

final class BannersPresenter {
    weak var view: BannersViewProtocol?
    weak var moduleOutput: BannersModuleOutputProtocol?

    private let wireframe: BannersWireframeProtocol
    private let interactor: BannersInteractorInputProtocol
    private let viewModelFactory: BannerViewModelFactoryProtocol

    private var banners: [Banner]?
    private var localizedResources: BannersLocalizedResources?

    init(
        interactor: BannersInteractorInputProtocol,
        wireframe: BannersWireframeProtocol,
        viewModelFactory: BannerViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideBanners() {
        let viewModel = viewModelFactory.createBannerViewModels(
            for: banners,
            localizedResources: localizedResources
        )

        view?.update(with: viewModel)
    }
}

// MARK: BannersPresenterProtocol

extension BannersPresenter: BannersPresenterProtocol {
    func setup() {
        provideBanners()
        interactor.setup(with: selectedLocale)
    }

    func action(for bannerId: String) {
        guard let banner = banners?.first(where: { $0.id == bannerId }) else {
            return
        }

        print(banner)
    }
}

// MARK: BannersInteractorOutputProtocol

extension BannersPresenter: BannersInteractorOutputProtocol {
    func didReceive(_ bannersFetchResult: BannersFetchResult) {
        banners = bannersFetchResult.banners
        localizedResources = bannersFetchResult.localizedResources

        provideBanners()

        moduleOutput?.didReceiveBanners(available: !bannersFetchResult.banners.isEmpty)
    }

    func didReceive(_ localizedResources: BannersLocalizedResources?) {
        self.localizedResources = localizedResources
        provideBanners()
    }

    func didReceive(_ error: any Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: selectedLocale
        )
    }
}

// MARK: BannersModuleInputProtocol

extension BannersPresenter: BannersModuleInputProtocol {
    var bannersAvailable: Bool {
        banners?.isEmpty != true
    }

    func refresh() {
        interactor.refresh(for: selectedLocale)
    }
}

// MARK: Localizable

extension BannersPresenter: Localizable {
    func applyLocalization() {
        guard view?.controller.isViewLoaded == true else { return }

        interactor.updateResources(for: selectedLocale)
    }
}
