import Foundation
import Foundation_iOS
import SubstrateSdk

struct GenericLedgerWalletViewFactory {
    static func createView(
        for application: GenericLedgerPolkadotApplicationProtocol,
        device: LedgerDeviceProtocol,
        index: UInt32,
        flow: WalletCreationFlow
    ) -> HardwareWalletAddressesViewProtocol? {
        let interactor = createInteractor(for: application, deviсe: device, index: index)
        let wireframe = GenericLedgerWalletWireframe(flow: flow)

        let presenter = GenericLedgerWalletPresenter(
            deviceName: device.name,
            deviceModel: device.model,
            appName: LedgerSubstrateApp.generic.displayName(for: nil),
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
        for application: GenericLedgerPolkadotApplicationProtocol,
        deviсe: LedgerDeviceProtocol,
        index: UInt32
    ) -> GenericLedgerWalletInteractor {
        GenericLedgerWalletInteractor(
            ledgerApplication: application,
            deviceId: deviсe.identifier,
            index: index,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
