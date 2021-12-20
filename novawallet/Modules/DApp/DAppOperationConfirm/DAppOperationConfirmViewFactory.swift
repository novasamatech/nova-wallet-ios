import Foundation
import SoraKeystore

struct DAppOperationConfirmViewFactory {
    static func createView(
        for request: DAppOperationRequest,
        delegate _: DAppOperationConfirmDelegate
    ) -> DAppOperationConfirmViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: request.chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: request.chain.chainId) else {
            return nil
        }

        guard let accountResponse = request.wallet.fetch(for: request.chain.accountRequest()) else {
            return nil
        }

        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            metaId: request.wallet.metaId,
            accountResponse: accountResponse
        )

        let interactor = DAppOperationConfirmInteractor(
            request: request,
            runtimeProvider: runtimeProvider,
            connection: connection,
            signingWrapper: signingWrapper,
            priceProviderFactory: PriceProviderFactory.shared
        )

        let wireframe = DAppOperationConfirmWireframe()

        let presenter = DAppOperationConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = DAppOperationConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
