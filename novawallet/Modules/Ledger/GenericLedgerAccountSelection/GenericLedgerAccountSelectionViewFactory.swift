import Foundation
import SubstrateSdk

struct GenericLedgerAccountSelectionViewFactory {
    static func createView(
        application: GenericLedgerSubstrateApplicationProtocol,
        device: LedgerDeviceProtocol,
        flow _: WalletCreationFlow
    ) -> GenericLedgerAccountSelectionViewProtocol? {
        let interactor = createInteractor(application: application, device: device)
        let wireframe = GenericLedgerAccountSelectionWireframe()

        let presenter = GenericLedgerAccountSelectionPresenter(interactor: interactor, wireframe: wireframe)

        let view = GenericLedgerAccountSelectionController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        application: GenericLedgerSubstrateApplicationProtocol,
        device: LedgerDeviceProtocol
    ) -> GenericLedgerAccountSelectionInteractor {
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        return GenericLedgerAccountSelectionInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            deviceId: device.identifier,
            ledgerApplication: application,
            requestFactory: requestFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
