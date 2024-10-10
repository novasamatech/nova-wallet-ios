import Foundation
import SoraFoundation
import SoraKeystore

struct PayCardViewFactory {
    static func createView() -> PayCardViewProtocol? {
        let interactor = createInteractor()
        let wireframe = PayCardWireframe()

        let presenter = PayCardPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

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
            payCardHookFactory: hooksFactory,
            payCardResourceProvider: MercuryoCardResourceProvider(),
            settingsManager: SettingsManager.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            pendingTimeout: MercuryoCardApi.pendingTimeout,
            logger: Logger.shared
        )
    }
}
