import Foundation
import SoraFoundation
import RobinHood
import FearlessUtils
import IrohaCrypto
import SoraKeystore

final class AccountManagementViewFactory: AccountManagementViewFactoryProtocol {
    static func createView(for walletId: String) -> AccountManagementViewProtocol? {
        let wireframe = AccountManagementWireframe()

        let view = AccountManagementViewController(nib: R.nib.accountManagementViewController)

        let iconGenerator = PolkadotIconGenerator()
        let viewModelFactory = ChainAccountViewModelFactory(iconGenerator: iconGenerator)

        let presenter = AccountManagementPresenter(
            viewModelFactory: viewModelFactory,
            walletId: walletId,
            logger: Logger.shared
        )

        let storageFacade = UserDataStorageFacade.shared

        let mapper = ManagedMetaAccountMapper()

        let walletRepository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(mapper)
        )

        let chainRepository = SubstrateRepositoryFactory().createChainRepository()

        let interactor = AccountManagementInteractor(
            walletRepository: AnyDataProviderRepository(walletRepository),
            chainRepository: chainRepository,
            operationManager: OperationManagerFacade.sharedManager,
            settings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared
        )

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
