import Foundation
import Foundation_iOS

enum VoteViewFactory {
    static func createView(
        walletNotificationService: WalletNotificationServiceProtocol,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) -> VoteViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = VoteInteractor(
            walletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            walletNotificationService: walletNotificationService
        )

        let wireframe = VoteWireframe(delegatedAccountSyncService: delegatedAccountSyncService)

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
