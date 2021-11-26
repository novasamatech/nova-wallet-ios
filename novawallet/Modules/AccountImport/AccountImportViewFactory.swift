import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import IrohaCrypto

final class AccountImportViewFactory {
    static func createViewForOnboarding(for secretSource: SecretSource) -> AccountImportViewProtocol? {
        guard let interactor = createAccountImportInteractor() else {
            return nil
        }

        let wireframe = AccountImportWireframe()
        return createView(
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

        return createView(for: secretSource, interactor: interactor, wireframe: wireframe)
    }

    static func createViewForSwitch(for secretSource: SecretSource) -> AccountImportViewProtocol? {
        guard let interactor = createAddAccountImportInteractor() else {
            return nil
        }

        let wireframe = SwitchAccount.AccountImportWireframe()
        return createView(for: secretSource, interactor: interactor, wireframe: wireframe)
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
            isEthereumBased: isEthereumBased
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

    private static func createView(
        for secretSource: SecretSource,
        interactor: BaseAccountImportInteractor,
        wireframe: AccountImportWireframeProtocol
    ) -> AccountImportViewProtocol? {
        let presenter = AccountImportPresenter(secretSource: secretSource)
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
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let keystore = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keystore)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let eventCenter = EventCenter.shared

        let interactor = AccountImportInteractor(
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            operationManager: OperationManagerFacade.sharedManager,
            settings: settings,
            keystoreImportService: keystoreImportService,
            eventCenter: eventCenter
        )

        return interactor
    }

    private static func createAddAccountImportInteractor() -> BaseAccountImportInteractor? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let keystore = Keychain()
        let accountOperationFactory = MetaAccountOperationFactory(keystore: keystore)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let eventCenter = EventCenter.shared

        let interactor = AddAccount
            .AccountImportInteractor(
                accountOperationFactory: accountOperationFactory,
                accountRepository: accountRepository,
                operationManager: OperationManagerFacade.sharedManager,
                settings: SelectedWalletSettings.shared,
                keystoreImportService: keystoreImportService,
                eventCenter: eventCenter
            )

        return interactor
    }

    private static func createChainAccountImportInteractor(
        isEthereumBased: Bool
    ) -> BaseAccountImportInteractor? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let keystore = Keychain()
        let accountOperationFactory = MetaAccountOperationFactory(keystore: keystore)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let eventCenter = EventCenter.shared

        let interactor = ImportChainAccount
            .AccountImportInteractor(
                metaAccountOperationFactory: accountOperationFactory,
                metaAccountRepository: accountRepository,
                operationManager: OperationManagerFacade.sharedManager,
                settings: SelectedWalletSettings.shared,
                keystoreImportService: keystoreImportService,
                eventCenter: eventCenter,
                isEthereumBased: isEthereumBased
            )

        return interactor
    }
}
