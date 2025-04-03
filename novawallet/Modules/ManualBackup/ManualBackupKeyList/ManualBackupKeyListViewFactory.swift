import Foundation
import Operation_iOS
import SubstrateSdk
import Foundation_iOS

struct ManualBackupKeyListViewFactory {
    static func createView(with metaAccount: MetaAccountModel) -> ManualBackupKeyListViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let viewModelFactory = ManualBackupKeyListViewModelFactory(
            localizationManager: LocalizationManager.shared,
            networkViewModelFactory: NetworkViewModelFactory()
        )

        let interactor = ManualBackupKeyListInteractor(
            chainRegistry: chainRegistry
        )

        let wireframe = ManualBackupKeyListWireframe()

        let presenter = ManualBackupKeyListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            metaAccount: metaAccount,
            logger: Logger.shared
        )

        let view = ManualBackupKeyListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
