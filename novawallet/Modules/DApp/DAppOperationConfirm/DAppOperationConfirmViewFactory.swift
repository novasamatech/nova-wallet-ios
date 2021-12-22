import Foundation
import SoraKeystore
import SoraFoundation

struct DAppOperationConfirmViewFactory {
    static func createView(
        for request: DAppOperationRequest,
        delegate: DAppOperationConfirmDelegate
    ) -> DAppOperationConfirmViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: request.chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: request.chain.chainId) else {
            return nil
        }

        let interactor = DAppOperationConfirmInteractor(
            request: request,
            runtimeProvider: runtimeProvider,
            connection: connection,
            keychain: Keychain(),
            priceProviderFactory: PriceProviderFactory.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = DAppOperationConfirmWireframe()

        let presenter = DAppOperationConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegate: delegate,
            logger: Logger.shared
        )

        let view = DAppOperationConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
