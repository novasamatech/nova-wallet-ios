import Foundation
import SoraFoundation

enum VoteViewFactory {
    static func createView() -> VoteViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = VoteInteractor(
            walletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared
        )

        let wireframe = VoteWireframe()

        let childPresenterFactory = VoteChildPresenterFactory(currencyManager: currencyManager)

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
