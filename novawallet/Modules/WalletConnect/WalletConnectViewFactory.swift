import Foundation

struct WalletConnectViewFactory {
    static func createView() -> WalletConnectViewProtocol? {
        let interactor = createInteractor()
        let wireframe = WalletConnectWireframe()

        let presenter = WalletConnectPresenter(
            interactor: interactor,
            wireframe: wireframe,
            logger: Logger.shared
        )

        let view = WalletConnectViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> WalletConnectInteractor {
        let metadata = WalletConnectMetadata.nova(with: ApplicationConfig.shared.walletConnectProjectId)
        let service = WalletConnectService(metadata: metadata)

        return .init(service: service, logger: Logger.shared)
    }
}
