import Foundation
import Keystore_iOS
import Foundation_iOS
import NovaCrypto
import Operation_iOS

final class AccountConfirmViewFactory: AccountConfirmViewFactoryProtocol {
    static func createViewForOnboarding(
        request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
    ) -> AccountConfirmViewProtocol? {
        guard let interactor = createAccountConfirmInteractor(
            for: request,
            metadata: metadata
        ) else {
            return nil
        }

        let wireframe = AccountConfirmWireframe()

        return createView(for: interactor, wireframe: wireframe)
    }

    static func createViewForAdding(
        request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
    ) -> AccountConfirmViewProtocol? {
        guard let interactor = createAddAccountConfirmInteractor(
            for: request,
            metadata: metadata
        ) else {
            return nil
        }

        let wireframe = AddAccount.AccountConfirmWireframe()

        return createView(for: interactor, wireframe: wireframe)
    }

    static func createViewForSwitch(
        request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
    ) -> AccountConfirmViewProtocol? {
        guard let interactor = createAddAccountConfirmInteractor(
            for: request,
            metadata: metadata
        ) else {
            return nil
        }

        let wireframe = SwitchAccount.AccountConfirmWireframe()
        return createView(for: interactor, wireframe: wireframe)
    }

    static func createViewForReplace(
        request: ChainAccountImportMnemonicRequest,
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id
    ) -> AccountConfirmViewProtocol? {
        guard let interactor = createAddChainAccountConfirmInteractor(
            for: metaAccountModel,
            request: request,
            chainModelId: chainModelId
        ) else {
            return nil
        }

        let wireframe = AddChainAccount.AccountConfirmWireframe()
        return createView(for: interactor, wireframe: wireframe)
    }

    private static func createView(
        for interactor: BaseAccountConfirmInteractor,
        wireframe: AccountConfirmWireframeProtocol
    ) -> AccountConfirmViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let mnemonicViewModelFactory = MnemonicViewModelFactory(localizationManager: localizationManager)
        var showsSkipButton = false

        #if F_DEV
            showsSkipButton = true
        #endif

        let presenter = AccountConfirmPresenter(
            wireframe: wireframe,
            interactor: interactor,
            mnemonicViewModelFactory: mnemonicViewModelFactory,
            localizationManager: localizationManager
        )

        let view = AccountConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager,
            showsSkipButton: showsSkipButton
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createView(
        for interactor: BaseChainAccountConfirmInteractor,
        wireframe: AccountConfirmWireframeProtocol
    ) -> AccountConfirmViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let mnemonicViewModelFactory = MnemonicViewModelFactory(localizationManager: localizationManager)
        var showsSkipButton = false

        #if F_DEV
            showsSkipButton = true
        #endif

        let presenter = AccountConfirmPresenter(
            wireframe: wireframe,
            interactor: interactor,
            mnemonicViewModelFactory: mnemonicViewModelFactory,
            localizationManager: localizationManager
        )

        let view = AccountConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager,
            showsSkipButton: showsSkipButton
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createAccountConfirmInteractor(
        for request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
    ) -> BaseAccountConfirmInteractor? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " "))
        else {
            return nil
        }

        let keychain = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keychain)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let interactor = AccountConfirmInteractor(
            request: request,
            mnemonic: mnemonic,
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            settings: settings,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared
        )

        return interactor
    }

    private static func createAddAccountConfirmInteractor(
        for request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
    ) -> BaseAccountConfirmInteractor? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " "))
        else {
            return nil
        }

        let keychain = Keychain()

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keychain)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let interactor = AddAccount
            .AccountConfirmInteractor(
                request: request,
                mnemonic: mnemonic,
                accountOperationFactory: accountOperationFactory,
                accountRepository: accountRepository,
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                settings: SelectedWalletSettings.shared,
                eventCenter: EventCenter.shared
            )

        return interactor
    }

    private static func createAddChainAccountConfirmInteractor(
        for metaAccountModel: MetaAccountModel,
        request: ChainAccountImportMnemonicRequest,
        chainModelId: ChainModel.Id
    ) -> BaseChainAccountConfirmInteractor? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: request.mnemonic)
        else {
            return nil
        }

        let keychain = Keychain()
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keychain)
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

        let interactor = AddChainAccount
            .AccountConfirmInteractor(
                metaAccountModel: metaAccountModel,
                request: request,
                chainModelId: chainModelId,
                mnemonic: mnemonic,
                metaAccountOperationFactory: accountOperationFactory,
                walletRepository: walletRepository,
                walletUpdateMediator: walletsUpdater,
                operationQueue: operationQueue,
                settings: SelectedWalletSettings.shared,
                eventCenter: EventCenter.shared
            )

        return interactor
    }
}
