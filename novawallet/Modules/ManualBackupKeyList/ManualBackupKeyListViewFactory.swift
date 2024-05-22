import Foundation
import RobinHood
import SubstrateSdk
import SoraFoundation

struct ManualBackupKeyListViewFactory {
    static func createView(with metaAccount: MetaAccountModel) -> ManualBackupKeyListViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let networkViewModelFactory = NetworkViewModelFactory()

        let interactor = ManualBackupKeyListInteractor(
            chainRegistry: chainRegistry
        )

        let wireframe = ManualBackupKeyListWireframe()

        let presenter = ManualBackupKeyListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            metaAccount: metaAccount,
            networkViewModelFactory: networkViewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = ManualBackupKeyListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
