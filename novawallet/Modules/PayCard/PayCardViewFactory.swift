import Foundation
import Foundation_iOS
import Keystore_iOS

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

        let logger = Logger.shared

        let paramsProvider = MercuryoCardParamsProvider(
            chainRegistry: chainRegistry,
            wallet: SelectedWalletSettings.shared.value,
            chainId: KnowChainId.polkadotAssetHub
        )
        let hooksFactory = MercuryoCardHookFactory(logger: logger)
        let resourceProvider = MercuryoCardResourceProvider()

        return PayCardInteractor(
            paramsProvider: paramsProvider,
            payCardHookFactory: hooksFactory,
            payCardResourceProvider: resourceProvider,
            settingsManager: SettingsManager.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            pendingTimeout: MercuryoApi.pendingTimeout,
            logger: logger
        )
    }
}
