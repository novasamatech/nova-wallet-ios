import Foundation
import SoraFoundation
import SubstrateSdk

struct GenericLedgerWalletViewFactory {
    static func createView(
        for application: GenericLedgerSubstrateApplicationProtocol,
        device: LedgerDeviceProtocol,
        flow: WalletCreationFlow
    ) -> HardwareWalletAddressesViewProtocol? {
        let interactor = createInteractor(for: application, deviсe: device)
        let wireframe = GenericLedgerWalletWireframe(flow: flow)

        let presenter = GenericLedgerWalletPresenter(
            deviceName: device.name,
            appName: application.displayName,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: ChainAccountViewModelFactory(iconGenerator: PolkadotIconGenerator()),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = HardwareWalletAddressesViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for application: GenericLedgerSubstrateApplicationProtocol,
        deviсe: LedgerDeviceProtocol
    ) -> GenericLedgerWalletInteractor {
        GenericLedgerWalletInteractor(
            ledgerApplication: application,
            deviceId: deviсe.identifier,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
