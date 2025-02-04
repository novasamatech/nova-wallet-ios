import Foundation

protocol BannersViewProtocol: ControllerBackedProtocol {
    func update(with viewModel: LoadableViewModelState<[BannerViewModel]>?)
}

protocol BannersPresenterProtocol: AnyObject {
    func setup()
}

protocol BannersInteractorInputProtocol: AnyObject {
    func setup(with locale: Locale)
    func updateResources(for locale: Locale)
}

protocol BannersInteractorOutputProtocol: AnyObject {
    func didReceive(_ bannersFetchResult: BannersFetchResult)
    func didReceive(_ localizedResources: BannersLocalizedResources?)
    func didReceive(_ error: Error)
}

protocol BannersWireframeProtocol: AlertPresentable, ErrorPresentable {}
