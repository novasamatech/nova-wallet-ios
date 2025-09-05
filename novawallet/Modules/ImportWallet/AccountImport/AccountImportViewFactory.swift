import Foundation
import Foundation_iOS
import Keystore_iOS
import Operation_iOS
import NovaCrypto

final class AccountImportViewFactory {
    static func createViewForOnboarding(for secretSource: SecretSource) -> AccountImportViewProtocol? {
        guard let interactor = createAccountImportInteractor() else {
            return nil
        }

        let wireframe = AccountImportWireframe()
        return createWalletImportView(
            for: secretSource,
            interactor: interactor,
            wireframe: wireframe
        )
    }

    static func createViewForAdding(for secretSource: SecretSource) -> AccountImportViewProtocol? {
        guard let interactor = createAddAccountImportInteractor() else {
            return nil
        }

        let wireframe = AddAccount.AccountImportWireframe()

        return createWalletImportView(for: secretSource, interactor: interactor, wireframe: wireframe)
    }

    static func createViewForSwitch(for secretSource: SecretSource) -> AccountImportViewProtocol? {
        guard let interactor = createAddAccountImportInteractor() else {
            return nil
        }

        let wireframe = SwitchAccount.AccountImportWireframe()
        return createWalletImportView(for: secretSource, interactor: interactor, wireframe: wireframe)
    }

    static func createViewForReplaceChainAccount(
        secretSource: SecretSource,
        modelId: ChainModel.Id,
        isEthereumBased: Bool,
        in wallet: MetaAccountModel
    ) -> AccountImportViewProtocol? {
        guard let interactor = createChainAccountImportInteractor(
            isEthereumBased: isEthereumBased
        ) else {
            return nil
        }

        let presenter = ImportChainAccount.AccountImportPresenter(
            secretSource: secretSource,
            metaAccountModel: wallet,
            chainModelId: modelId,
            isEthereumBased: isEthereumBased,
            metadataFactory: ChainAccountImportMetadataFactory(isEthereumBased: isEthereumBased)
        )

        let localizationManager = LocalizationManager.shared

        let view = AccountImportViewController(presenter: presenter, localizationManager: localizationManager)
        let wireframe = ImportChainAccount.AccountImportWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        presenter.localizationManager = localizationManager

        return view
    }

    private static func createWalletImportView(
        for secretSource: SecretSource,
        interactor: BaseAccountImportInteractor,
        wireframe: AccountImportWireframeProtocol
    ) -> AccountImportViewProtocol? {
        let presenter = AccountImportPresenter(
            secretSource: secretSource,
            metadataFactory: WalletImportMetadataFactory()
        )

        let localizationManager = LocalizationManager.shared

        let view = AccountImportViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        presenter.localizationManager = localizationManager

        return view
    }

    private static func createAccountImportInteractor() -> BaseAccountImportInteractor? {
        guard let secretImportService: SecretImportServiceProtocol =
            URLHandlingServiceFacade.shared.findInternalService()
        else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let keystore = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactoryProvider = MetaAccountOperationFactoryProvider(keystore: keystore)

        let eventCenter = EventCenter.shared

        let interactor = AccountImportInteractor(
            metaAccountOperationFactoryProvider: accountOperationFactoryProvider,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            settings: settings,
            secretImportService: secretImportService,
            eventCenter: eventCenter
        )

        return interactor
    }

    private static func createAddAccountImportInteractor() -> BaseAccountImportInteractor? {
        guard let secretImportService: SecretImportServiceProtocol =
            URLHandlingServiceFacade.shared.findInternalService()
        else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let keystore = Keychain()
        let accountOperationFactoryProvider = MetaAccountOperationFactoryProvider(keystore: keystore)

        let eventCenter = EventCenter.shared

        let interactor = AddAccount
            .AccountImportInteractor(
                metaAccountOperationFactoryProvider: accountOperationFactoryProvider,
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                settings: SelectedWalletSettings.shared,
                secretImportService: secretImportService,
                eventCenter: eventCenter
            )

        return interactor
    }

    private static func createChainAccountImportInteractor(
        isEthereumBased _: Bool
    ) -> BaseAccountImportInteractor? {
        guard let secretImportService: SecretImportServiceProtocol =
            URLHandlingServiceFacade.shared.findInternalService()
        else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let keystore = Keychain()
        let accountOperationFactoryProvider = MetaAccountOperationFactoryProvider(keystore: keystore)
        let walletRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let walletRepository = walletRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )
        let walletStorageCleaner = WalletStorageCleanerFactory.createWalletStorageCleaner(
            using: operationQueue
        )
        let walletsUpdater = WalletUpdateMediator(
            selectedWalletSettings: SelectedWalletSettings.shared,
            repository: walletRepository,
            walletsCleaner: walletStorageCleaner,
            operationQueue: operationQueue
        )

        let eventCenter = EventCenter.shared

        let interactor = ImportChainAccount
            .AccountImportInteractor(
                metaAccountOperationFactoryProvider: accountOperationFactoryProvider,
                operationQueue: operationQueue,
                settings: SelectedWalletSettings.shared,
                walletRepository: walletRepository,
                walletUpdateMediator: walletsUpdater,
                secretImportService: secretImportService,
                eventCenter: eventCenter
            )

        return interactor
    }
}
