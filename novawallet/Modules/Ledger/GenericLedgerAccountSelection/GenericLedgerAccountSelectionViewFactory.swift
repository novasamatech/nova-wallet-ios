import Foundation
import SubstrateSdk
import Foundation_iOS

struct GenericLedgerAccountSelectionViewFactory {
    static func createView(
        application: GenericLedgerPolkadotApplicationProtocol,
        device: LedgerDeviceProtocol,
        flow: WalletCreationFlow
    ) -> GenericLedgerAccountSelectionViewProtocol? {
        let interactor = createInteractor(application: application, device: device)
        let wireframe = GenericLedgerAccountSelectionWireframe(
            flow: flow,
            application: application,
            device: device
        )

        let presenter = GenericLedgerAccountSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: GenericLedgerAccountVMFactory(),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = GenericLedgerAccountSelectionController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        application: GenericLedgerPolkadotApplicationProtocol,
        device: LedgerDeviceProtocol
    ) -> GenericLedgerAccountSelectionInteractor {
        let accountFetchFactory = GenericLedgerAccountFetchFactory(
            deviceId: device.identifier,
            ledgerApplication: application
        )

        return GenericLedgerAccountSelectionInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            accountFetchFactory: accountFetchFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
