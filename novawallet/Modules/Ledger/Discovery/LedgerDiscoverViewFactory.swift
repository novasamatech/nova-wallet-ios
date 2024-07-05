import Foundation
import SoraFoundation

struct LedgerDiscoverViewFactory {
    static func createExistingPairingView(
        chain: ChainModel,
        wallet: MetaAccountModel
    ) -> ControllerBackedProtocol? {
        let ledgerConnection = LedgerConnectionManager(logger: Logger.shared)

        let ledgerApplication: LedgerAccountRetrievable = if chain.supportsGenericLedgerApp {
            MigrationLedgerSubstrateApplication(
                connectionManager: ledgerConnection,
                chainRegistry: ChainRegistryFacade.sharedRegistry,
                supportedApps: SupportedLedgerApp.substrate()
            )
        } else {
            LedgerApplication(
                connectionManager: ledgerConnection,
                supportedApps: SupportedLedgerApp.substrate()
            )
        }

        let interactor = LedgerDiscoverInteractor(
            chain: chain,
            ledgerApplication: ledgerApplication,
            ledgerConnection: ledgerConnection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let wireframe = LedgerDiscoverAccountAddWireframe(
            wallet: wallet,
            application: ledgerApplication,
            chain: chain
        )
        
        let appName = chain.supportsGenericLedgerApp ?
            LedgerSubstrateApp.migration.displayName(for: nil) :
            chain.name

        return createView(interactor: interactor, wireframe: wireframe, appName: appName)
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
            application: ledgerApplication,
            chain: chain
        )

        return createView(interactor: interactor, wireframe: wireframe, appName: chain.name)
    }

    static func createGenericLedgerView(for flow: WalletCreationFlow) -> ControllerBackedProtocol? {
        let ledgerConnection = LedgerConnectionManager(logger: Logger.shared)

        let ledgerApplication = GenericLedgerSubstrateApplication(connectionManager: ledgerConnection)

        let interactor = GenericLedgerDiscoverInteractor(
            ledgerApplication: ledgerApplication,
            ledgerConnection: ledgerConnection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let wireframe = GenericLedgerDiscoverWireframe(application: ledgerApplication, flow: flow)

        return createView(
            interactor: interactor,
            wireframe: wireframe,
            appName: LedgerSubstrateApp.generic.displayName(for: nil)
        )
    }

    private static func createView(
        interactor: LedgerPerformOperationInteractor,
        wireframe: LedgerDiscoverWireframeProtocol,
        appName: String
    ) -> ControllerBackedProtocol? {
        let presenter = LedgerDiscoverPresenter(
            appName: appName,
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
