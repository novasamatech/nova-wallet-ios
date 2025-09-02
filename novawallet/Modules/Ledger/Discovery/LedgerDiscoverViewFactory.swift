import Foundation
import Foundation_iOS

struct LedgerDiscoverViewFactory {
    static func createExistingPairingView(
        chain: ChainModel,
        wallet: MetaAccountModel
    ) -> ControllerBackedProtocol? {
        let ledgerConnection = LedgerConnectionManager(logger: Logger.shared)

        let ledgerApplication = createLegacyLedgerApplication(for: chain, connection: ledgerConnection)

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

        let appName = createLedgerAppName(for: chain)

        return createView(interactor: interactor, wireframe: wireframe, appName: appName)
    }

    static func createNewPairingView(
        chain: ChainModel,
        accountsStore: LedgerAccountsStore
    ) -> ControllerBackedProtocol? {
        let ledgerConnection = LedgerConnectionManager(logger: Logger.shared)

        let ledgerApplication = createLegacyLedgerApplication(
            for: chain,
            connection: ledgerConnection
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

        let appName = createLedgerAppName(for: chain)

        return createView(interactor: interactor, wireframe: wireframe, appName: appName)
    }

    static func createGenericLedgerView(for flow: WalletCreationFlow) -> ControllerBackedProtocol? {
        let ledgerConnection = LedgerConnectionManager(logger: Logger.shared)

        let ledgerApplication = GenericLedgerPolkadotApplication(connectionManager: ledgerConnection)

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

    static func createAddEvmGenericLedgerView(to wallet: MetaAccountModel) -> ControllerBackedProtocol? {
        let ledgerConnection = LedgerConnectionManager(logger: Logger.shared)

        let ledgerApplication = GenericLedgerPolkadotApplication(connectionManager: ledgerConnection)

        let interactor = GenericLedgerDiscoverInteractor(
            ledgerApplication: ledgerApplication,
            ledgerConnection: ledgerConnection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let wireframe = GenericLedgerAddEvmDiscoverWireframe(application: ledgerApplication, wallet: wallet)

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

    private static func createLegacyLedgerApplication(
        for chain: ChainModel,
        connection: LedgerConnectionManagerProtocol
    ) -> LedgerAccountRetrievable {
        if chain.supportsGenericLedgerApp {
            return MigrationLedgerPolkadotApplication(
                connectionManager: connection,
                chainRegistry: ChainRegistryFacade.sharedRegistry,
                supportedApps: SupportedLedgerApp.substrate()
            )
        } else {
            return LedgerApplication(
                connectionManager: connection,
                supportedApps: SupportedLedgerApp.substrate()
            )
        }
    }

    private static func createLedgerAppName(for chain: ChainModel) -> String {
        chain.supportsGenericLedgerApp ?
            LedgerSubstrateApp.migration.displayName(for: nil) :
            chain.name
    }
}
