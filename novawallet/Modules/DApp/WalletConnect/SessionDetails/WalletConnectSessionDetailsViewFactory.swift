import Foundation
import Foundation_iOS

struct WalletConnectSessionDetailsViewFactory {
    static func createView(
        for session: WalletConnectSession,
        dappMediator: DAppInteractionMediating
    ) -> WalletConnectSessionDetailsViewProtocol? {
        guard let interactor = createInteractor(for: session, dappMediator: dappMediator) else {
            return nil
        }

        let wireframe = WalletConnectSessionDetailsWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = WalletConnectSessionDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: WalletConnectSessionViewModelFactory(),
            session: session,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = WalletConnectSessionViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createInteractor(
        for session: WalletConnectSession,
        dappMediator: DAppInteractionMediating
    ) -> WalletConnectSessionDetailsInteractor? {
        guard
            let walletConnect = dappMediator.children.first(
                where: { $0 is WalletConnectDelegateInputProtocol }
            ) as? WalletConnectDelegateInputProtocol else {
            return nil
        }

        return .init(walletConnect: walletConnect, sessionId: session.sessionId)
    }
}
