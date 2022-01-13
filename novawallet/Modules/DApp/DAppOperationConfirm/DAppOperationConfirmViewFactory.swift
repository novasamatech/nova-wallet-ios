import Foundation
import SoraKeystore
import SoraFoundation

struct DAppOperationConfirmViewFactory {
    static func createView(
        for request: DAppOperationRequest,
        type: DAppSigningType,
        delegate: DAppOperationConfirmDelegate
    ) -> DAppOperationConfirmViewProtocol? {
        guard let assetInfo = request.chain.utilityAssets().first?.displayInfo(with: request.chain.icon) else {
            return nil
        }

        let maybeInteractor: (DAppOperationBaseInteractor & DAppOperationConfirmInteractorInputProtocol)?

        switch type {
        case .extrinsic:
            maybeInteractor = createExtrinsicInteractor(for: request)
        case .bytes:
            maybeInteractor = createSignBytesInteractor(for: request)
        }

        guard let interactor = maybeInteractor else {
            return nil
        }

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
        maybeInteractor?.presenter = presenter

        return view
    }

    private static func createExtrinsicInteractor(
        for request: DAppOperationRequest
    ) -> DAppOperationConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: request.chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: request.chain.chainId) else {
            return nil
        }

        return DAppOperationConfirmInteractor(
            request: request,
            runtimeProvider: runtimeProvider,
            connection: connection,
            keychain: Keychain(),
            priceProviderFactory: PriceProviderFactory.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }

    private static func createSignBytesInteractor(
        for request: DAppOperationRequest
    ) -> DAppSignBytesConfirmInteractor {
        DAppSignBytesConfirmInteractor(request: request, keychain: Keychain())
    }
}
