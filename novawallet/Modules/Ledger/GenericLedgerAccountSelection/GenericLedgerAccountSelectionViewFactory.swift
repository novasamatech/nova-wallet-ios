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
            assetTokenFormatter: AssetBalanceFormatterFactory(),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = GenericLedgerAccountSelectionController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        application: GenericLedgerPolkadotApplicationProtocol,
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
