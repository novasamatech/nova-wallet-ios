import Foundation
import Foundation_iOS
import Operation_iOS
import SubstrateSdk
import NovaCrypto
import Keystore_iOS

final class AccountManagementViewFactory: AccountManagementViewFactoryProtocol {
    static func createView(for walletId: String) -> AccountManagementViewProtocol? {
        let wireframe = AccountManagementWireframe()

        let iconGenerator = PolkadotIconGenerator()
        let viewModelFactory = AccountManagementViewModelFactory()
        let chainAccountViewModelFactory = ChainAccountViewModelFactory(iconGenerator: iconGenerator)

        let presenter = AccountManagementPresenter(
            viewModelFactory: viewModelFactory,
            chainAccountViewModelFactory: chainAccountViewModelFactory,
            walletId: walletId,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        presenter.localizationManager = LocalizationManager.shared

        let storageFacade = UserDataStorageFacade.shared

        let mapper = ManagedMetaAccountMapper()

        let walletRepository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(mapper)
        )

        let chainRepository = SubstrateRepositoryFactory().createChainRepository()

        let view = AccountManagementViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        let keystore = Keychain()

        let interactor = AccountManagementInteractor(
            cloudBackupSyncService: CloudBackupSyncMediatorFacade.sharedMediator.syncService,
            walletCreationRequestFactory: WalletCreationRequestFactory(),
            walletRepository: AnyDataProviderRepository(walletRepository),
            accountOperationFactory: MetaAccountOperationFactory(keystore: keystore),
            chainRepository: chainRepository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            settings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            keystore: keystore,
            chainsFilter: AccountManagementFilter()
        )

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
