import Foundation

struct PayCardViewFactory {
    static func createView() -> PayCardViewProtocol? {
        let interactor = createInteractor()
        let wireframe = PayCardWireframe()

        let presenter = PayCardPresenter(interactor: interactor, wireframe: wireframe)

        let view = PayCardViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> PayCardInteractor {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let hooksFactory = MercuryoCardHookFactory(
            chainRegistry: chainRegistry,
            wallet: SelectedWalletSettings.shared.value,
            chainId: KnowChainId.polkadot,
            logger: Logger.shared
        )

        return PayCardInteractor(
            payCardModelFactory: hooksFactory,
            payCardResourceProvider: MercuryoCardResourceProvider(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
