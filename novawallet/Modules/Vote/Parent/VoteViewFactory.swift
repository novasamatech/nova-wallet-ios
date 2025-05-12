import Foundation
import Foundation_iOS

enum VoteViewFactory {
    static func createView() -> ScrollViewHostControlling? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let childPresenterFactory = VoteChildPresenterFactory(
            currencyManager: currencyManager,
            applicationHandler: SecurityLayerService.shared.applicationHandlingProxy.addApplicationHandler()
        )

        let interactor = VoteInteractor(
            walletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared
        )

        let presenter = VotePresenter(interactor: interactor, childPresenterFactory: childPresenterFactory)

        let view = VoteViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
