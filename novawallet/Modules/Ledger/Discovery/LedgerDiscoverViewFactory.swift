import Foundation
import SoraFoundation

struct LedgerDiscoverViewFactory {
    static func createView(chain: ChainModel, accountsStore: LedgerAccountsStore) -> ControllerBackedProtocol? {
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

        let wireframe = LedgerDiscoverWireframe(accountsStore: accountsStore, application: ledgerApplication)

        let presenter = LedgerDiscoverPresenter(
            chain: chain,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = LedgerPerformOperationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.basePresenter = presenter

        return view
    }
}
