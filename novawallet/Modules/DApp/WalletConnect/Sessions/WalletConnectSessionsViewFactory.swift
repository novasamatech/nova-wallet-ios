import Foundation

struct WalletConnectSessionsViewFactory {
    static func createView(
        with dappMediator: DAppInteractionMediating
    ) -> WalletConnectSessionsViewProtocol? {
        guard let interactor = createInteractor(with: dappMediator) else {
            return nil
        }

        let wireframe = WalletConnectSessionsWireframe()

        let presenter = WalletConnectSessionsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            logger: Logger.shared
        )

        let view = WalletConnectSessionsViewController(presenter: presenter)

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
