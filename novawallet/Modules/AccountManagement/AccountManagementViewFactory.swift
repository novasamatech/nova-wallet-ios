import Foundation
import SoraFoundation
import RobinHood
import SubstrateSdk
import IrohaCrypto
import SoraKeystore

final class AccountManagementViewFactory: AccountManagementViewFactoryProtocol {
    static func createView(for walletId: String) -> AccountManagementViewProtocol? {
        let wireframe = AccountManagementWireframe()

        let iconGenerator = PolkadotIconGenerator()
        let viewModelFactory = ChainAccountViewModelFactory(iconGenerator: iconGenerator)

        let presenter = AccountManagementPresenter(
            viewModelFactory: viewModelFactory,
            walletId: walletId,
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

        let interactor = AccountManagementInteractor(
            walletRepository: AnyDataProviderRepository(walletRepository),
            chainRepository: chainRepository,
            operationManager: OperationManagerFacade.sharedManager,
            settings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            keystore: Keychain()
        )

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
