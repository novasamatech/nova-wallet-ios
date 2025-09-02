import Foundation
import Foundation_iOS

struct ChangeWatchOnlyViewFactory {
    static func createView(
        for wallet: MetaAccountModel,
        chain: ChainModel
    ) -> ChangeWatchOnlyViewProtocol? {
        guard let interactor = createInteractor(for: wallet, chain: chain) else {
            return nil
        }

        let wireframe = ChangeWatchOnlyWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = ChangeWatchOnlyPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            logger: Logger.shared,
            localizationManager: localizationManager
        )

        let view = ChangeWatchOnlyViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for wallet: MetaAccountModel,
        chain: ChainModel
    ) -> ChangeWatchOnlyInteractor? {
        let facade = UserDataStorageFacade.shared
        let repository = AccountRepositoryFactory(storageFacade: facade).createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        return ChangeWatchOnlyInteractor(
            chain: chain,
            wallet: wallet,
            settings: SelectedWalletSettings.shared,
            repository: repository,
            walletOperationFactory: WatchOnlyWalletOperationFactory(),
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
