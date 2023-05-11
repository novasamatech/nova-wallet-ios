import Foundation
import SoraFoundation

struct WalletConnectSessionsViewFactory {
    static func createView(
        with dappMediator: DAppInteractionMediating
    ) -> WalletConnectSessionsViewProtocol? {
        guard let interactor = createInteractor(with: dappMediator) else {
            return nil
        }

        let wireframe = WalletConnectSessionsWireframe(dappMediator: dappMediator)

        let localizationManager = LocalizationManager.shared

        let presenter = WalletConnectSessionsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: WalletConnectSessionsViewModelFactory(),
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = WalletConnectSessionsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        with dappMediator: DAppInteractionMediating
    ) -> WalletConnectSessionsInteractor? {
        guard
            let walletConnect = dappMediator.children.first(
                where: { $0 is WalletConnectDelegateInputProtocol }
            ) as? WalletConnectDelegateInputProtocol else {
            return nil
        }

        return .init(walletConnect: walletConnect)
    }
}
