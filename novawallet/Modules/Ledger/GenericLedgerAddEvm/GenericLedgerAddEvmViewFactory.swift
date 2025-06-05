import Foundation
import Keystore_iOS
import Foundation_iOS

struct GenericLedgerAddEvmViewFactory {
    static func createView(
        wallet: MetaAccountModel,
        application: GenericLedgerPolkadotApplicationProtocol,
        device: LedgerDeviceProtocol
    ) -> GenericLedgerAccountSelectionViewProtocol? {
        let interactor = createInteractor(
            wallet: wallet,
            application: application,
            device: device
        )

        let wireframe = GenericLedgerAddEvmWireframe()

        let presenter = GenericLedgerAddEvmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            deviceName: device.name,
            deviceModel: device.model,
            appName: LedgerSubstrateApp.generic.displayName(for: nil),
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
}

private extension GenericLedgerAddEvmViewFactory {
    static func createInteractor(
        wallet: MetaAccountModel,
        application: GenericLedgerPolkadotApplicationProtocol,
        device: LedgerDeviceProtocol
    ) -> GenericLedgerAddEvmInteractor {
        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(for: nil, sortDescriptors: [])

        let fetchFactory = GenericLedgerAccountFetchFactory(
            deviceId: device.identifier,
            ledgerApplication: application
        )

        return GenericLedgerAddEvmInteractor(
            wallet: wallet,
            accountFetchFactory: fetchFactory,
            walletOperationFactory: GenericLedgerWalletOperationFactory(),
            walletRepository: walletRepository,
            keystore: Keychain(),
            walletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
