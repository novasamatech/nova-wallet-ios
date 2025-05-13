import Foundation
import Foundation_iOS

struct NavigationRootViewFactory {
    static func createView(
        with child: ScrollViewHostControlling,
        serviceCoordinator: ServiceCoordinatorProtocol
    ) -> NavigationRootViewProtocol? {
        let dappMediator = serviceCoordinator.dappMediator

        guard let walletConnect = dappMediator.children.first(
            where: { $0 is WalletConnectDelegateInputProtocol }
        ) as? WalletConnectDelegateInputProtocol else {
            return nil
        }

        let interactor = NavigationRootInteractor(
            eventCenter: EventCenter.shared,
            walletSettings: SelectedWalletSettings.shared,
            walletConnect: walletConnect,
            walletNotificationService: serviceCoordinator.walletNotificationService
        )

        let wireframe = NavigationRootWireframe(serviceCoordinator: serviceCoordinator)

        let presenter = NavigationRootPresenter(
            interactor: interactor,
            wireframe: wireframe,
            walletSwitchViewModelFactory: WalletSwitchViewModelFactory(),
            localizationManager: LocalizationManager.shared
        )

        let view = NavigationRootViewController(scrollHost: child, presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
