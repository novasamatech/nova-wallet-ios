import Foundation
import SoraFoundation

enum VoteViewFactory {
    static func createView() -> VoteViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let proxyNotificationService = WalletNotificationService(
            proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactory.shared,
            logger: Logger.shared
        )

        let interactor = VoteInteractor(
            walletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            proxyNotificationService: proxyNotificationService
        )

        let wireframe = VoteWireframe()

        let childPresenterFactory = VoteChildPresenterFactory(
            currencyManager: currencyManager,
            applicationHandler: SecurityLayerService.shared.applicationHandlingProxy.addApplicationHandler()
        )

        let presenter = VotePresenter(
            interactor: interactor,
            wireframe: wireframe,
            childPresenterFactory: childPresenterFactory
        )

        let view = VoteViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
