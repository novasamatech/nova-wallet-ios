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
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: request.chain.chainId),
            let assetInfo = request.chain.utilityAssets().first?.displayInfo(with: request.chain.icon) else {
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

        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let presenter = DAppOperationConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegate: delegate,
            viewModelFactory: DAppOperationConfirmViewModelFactory(),
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: LocalizationManager.shared,
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
