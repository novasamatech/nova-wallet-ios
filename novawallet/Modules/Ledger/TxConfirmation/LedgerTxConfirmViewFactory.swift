import Foundation
import SoraFoundation
import SoraKeystore

struct LedgerTxConfirmViewFactory {
    static func createView(
        with signingData: Data,
        metaId: String,
        chainId: ChainModel.Id,
        completion: @escaping TransactionSigningClosure
    ) -> ControllerBackedProtocol? {
        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(for: nil, sortDescriptors: [])

        let ledgerConnection = LedgerConnectionManager(logger: Logger.shared)
        let ledgerApplication = LedgerApplication(
            connectionManager: ledgerConnection,
            supportedApps: SupportedLedgerApp.substrate()
        )

        let interactor = LedgerTxConfirmInteractor(
            signingData: signingData,
            metaId: metaId,
            chainId: chainId,
            ledgerConnection: ledgerConnection,
            ledgerApplication: ledgerApplication,
            walletRepository: walletRepository,
            signatureVerifier: SignatureVerificationWrapper(),
            keystore: Keychain(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = LedgerTxConfirmWireframe()

        let chainName = ChainRegistryFacade.sharedRegistry.getChain(for: chainId)?.name ?? ""

        let presenter = LedgerTxConfirmPresenter(
            chainName: chainName,
            interactor: interactor,
            wireframe: wireframe,
            completion: completion,
            localizationManager: LocalizationManager.shared
        )

        let view = LedgerTxConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
