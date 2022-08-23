import Foundation
import SoraFoundation

struct LedgerDiscoverViewFactory {
    static func createView(chain: ChainModel, accountsStore: LedgerAccountsStore) -> LedgerDiscoverViewProtocol? {
        let ledgerConnection = LedgerConnectionManager(logger: Logger.shared)

        let ledgerApplication = LedgerApplication(
            connectionManager: ledgerConnection,
            supportedApps: SupportedLedgerApp.substrate()
        )

        let interactor = LedgerDiscoverInteractor(
            chain: chain,
            ledgerApplication: ledgerApplication,
            ledgerConnection: ledgerConnection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let wireframe = LedgerDiscoverWireframe(accountsStore: accountsStore)

        let presenter = LedgerDiscoverPresenter(
            chain: chain,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = LedgerDiscoverViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
