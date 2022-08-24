import Foundation
import SoraFoundation

struct LedgerNetworkSelectionViewFactory {
    static func createView() -> LedgerNetworkSelectionViewProtocol? {
        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(for: nil, sortDescriptors: [])

        let ledgerAccountsStore = LedgerAccountsStore(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            supportedApps: SupportedLedgerApp.all(),
            walletId: nil,
            repository: walletRepository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let interactor = LedgerNetworkSelectionInteractor(accountsStore: ledgerAccountsStore)
        let wireframe = LedgerNetworkSelectionWireframe(accountsStore: ledgerAccountsStore)

        let presenter = LedgerNetworkSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = LedgerNetworkSelectionViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
