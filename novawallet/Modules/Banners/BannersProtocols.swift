import Foundation
import UIKit

// MARK: Module Interface

enum BannersState {
    case loading
    case available
    case unavailable
}

protocol BannersModuleInputOwnerProtocol: AnyObject {
    var bannersModule: BannersModuleInputProtocol? { get set }
}

protocol BannersModuleInputProtocol: AnyObject {
    var bannersState: BannersState { get }
    var locale: Locale { get }

    func setup()
    func refresh()
    func updateLocale(_ newLocale: Locale)
}

protocol BannersModuleOutputProtocol: AnyObject {
    func didUpdateContent(state: BannersState)
    func didReceiveBanners(state: BannersState)
    func didReceive(_ error: Error)
}

protocol BannersViewProviderProtocol: ControllerBackedProtocol {
    func getMaxBannerHeight() -> CGFloat
}

extension BannersViewProviderProtocol {
    func setupBanners(
        on parent: ControllerBackedProtocol?,
        view: UIView
    ) {
        guard
            let parentController = parent?.controller,
            let childView = controller.view
        else { return }

        parentController.addChild(controller)
        view.addSubview(childView)

        childView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        controller.didMove(toParent: parentController)
    }
}

// MARK: Inner Interfaces

protocol BannersViewProtocol: ControllerBackedProtocol, BannersViewProviderProtocol {
    func update(with viewModel: LoadableViewModelState<BannersWidgetViewModel>?)
    func didCloseBanner(updatedViewModel: BannersWidgetViewModel)
}

protocol BannersPresenterProtocol: AnyObject {
    func setup()
    func action(for bannerId: String)
    func closeBanner(with id: String)
}

protocol BannersInteractorInputProtocol: AnyObject {
    func setup(with locale: Locale)
    func refresh(for locale: Locale)
    func updateResources(for locale: Locale)
    func closeBanner(with id: String)
}

protocol BannersInteractorOutputProtocol: AnyObject {
    func didReceive(_ bannersFetchResult: BannersFetchResult)
    func didReceive(_ updatedLocalizedResources: BannersLocalizedResources?)
    func didReceive(_ updatedClosedBanners: ClosedBanners)
    func didReceive(_ error: Error)
}

protocol BannersWireframeProtocol {
    func openActionLink(urlString: String)
}
