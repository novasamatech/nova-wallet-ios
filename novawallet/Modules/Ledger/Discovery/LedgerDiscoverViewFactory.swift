import Foundation
import SoraFoundation

struct LedgerDiscoverViewFactory {
    static func createExistingPairingView(
        chain: ChainModel,
        wallet: MetaAccountModel
    ) -> ControllerBackedProtocol? {
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

        let wireframe = LedgerDiscoverAccountAddWireframe(wallet: wallet, application: ledgerApplication)

        return createView(interactor: interactor, wireframe: wireframe, chain: chain)
    }

    static func createNewPairingView(
        chain: ChainModel,
        accountsStore: LedgerAccountsStore
    ) -> ControllerBackedProtocol? {
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

        let wireframe = LedgerDiscoverWalletCreateWireframe(
            accountsStore: accountsStore,
            application: ledgerApplication
        )

        return createView(interactor: interactor, wireframe: wireframe, chain: chain)
    }

    private static func createView(
        interactor: LedgerDiscoverInteractor,
        wireframe: LedgerDiscoverWireframeProtocol,
        chain: ChainModel
    ) -> ControllerBackedProtocol? {
        let presenter = LedgerDiscoverPresenter(
            chain: chain,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = LedgerPerformOperationViewController(
            basePresenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.basePresenter = presenter

        return view
    }
}
