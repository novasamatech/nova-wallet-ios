import Foundation
import UIKit

// MARK: Module Interface

protocol BannersModuleInputOwnerProtocol: AnyObject {
    var bannersModule: BannersModuleInputProtocol? { get set }
}

protocol BannersModuleInputProtocol: AnyObject {
    var bannersAvailable: Bool { get }

    func refresh()
}

protocol BannersModuleOutputProtocol: AnyObject {
    func didReceiveBanners(available: Bool)
}

protocol BannersViewProviderProtocol: ControllerBackedProtocol {}

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
    func update(with viewModel: LoadableViewModelState<[BannerViewModel]>?)
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
    func didReceive(_ updatedClosedBannerIds: Set<String>?)
    func didReceive(_ error: Error)
}

protocol BannersWireframeProtocol: AlertPresentable, ErrorPresentable {}
