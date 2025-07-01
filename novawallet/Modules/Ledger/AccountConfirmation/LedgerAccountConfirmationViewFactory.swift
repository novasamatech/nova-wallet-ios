import Foundation
import Foundation_iOS
import SubstrateSdk
import Operation_iOS
import Keystore_iOS

struct LedgerAccountConfirmationViewFactory {
    static func createAddAccountView(
        wallet: MetaAccountModel,
        chain: ChainModel,
        device: LedgerDeviceProtocol,
        application: LedgerAccountRetrievable
    ) -> LedgerAccountConfirmationViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: OperationManagerFacade.sharedDefaultQueue)
        )

        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(for: nil, sortDescriptors: [])

        let interactor = LedgerAddAccountConfirmationInteractor(
            wallet: wallet,
            chain: chain,
            deviceId: device.identifier,
            application: application,
            requestFactory: requestFactory,
            connection: connection,
            runtimeService: runtimeService,
            keystore: Keychain(),
            walletRepository: walletRepository,
            settings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = LedgerAddAccountConfirmationWireframe()

        return createView(
            chain: chain,
            device: device,
            interactor: interactor,
            wireframe: wireframe
        )
    }

    static func createNewWalletView(
        chain: ChainModel,
        device: LedgerDeviceProtocol,
        application: LedgerAccountRetrievable,
        accountsStore: LedgerAccountsStore
    ) -> LedgerAccountConfirmationViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: OperationManagerFacade.sharedDefaultQueue)
        )

        let interactor = LedgerWalletAccountConfirmationInteractor(
            chain: chain,
            deviceId: device.identifier,
            application: application,
            accountsStore: accountsStore,
            requestFactory: requestFactory,
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = LedgerWalletAccountConfirmationWireframe()

        return createView(
            chain: chain,
            device: device,
            interactor: interactor,
            wireframe: wireframe
        )
    }
}

private extension LedgerAccountConfirmationViewFactory {
    static func createView(
        chain: ChainModel,
        device: LedgerDeviceProtocol,
        interactor: LedgerBaseAccountConfirmationInteractor & LedgerAccountConfirmationInteractorInputProtocol,
        wireframe: LedgerAccountConfirmationWireframeProtocol
    ) -> LedgerAccountConfirmationViewProtocol? {
        guard let utilityAsset = chain.utilityAsset() else {
            return nil
        }

        let tokenFormatter = AssetBalanceFormatterFactory().createTokenFormatter(
            for: utilityAsset.displayInfo
        )

        let presenter = LedgerAccountConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            deviceName: device.name,
            deviceModel: device.model,
            tokenFormatter: tokenFormatter,
            localizationManager: LocalizationManager.shared
        )

        let view = LedgerAccountConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
