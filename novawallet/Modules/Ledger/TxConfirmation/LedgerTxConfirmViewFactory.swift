import Foundation
import SoraFoundation
import SoraKeystore

struct LedgerTxConfirmViewFactory {
    static func createView(
        with signingData: Data,
        metaId: String,
        chainId: ChainModel.Id,
        params: LedgerTxConfirmationParams,
        completion: @escaping TransactionSigningClosure
    ) -> ControllerBackedProtocol? {
        guard let interactor = createInteractor(
            signingData: signingData,
            metaId: metaId,
            chainId: chainId,
            params: params
        ) else {
            completion(.failure(HardwareSigningError.signingCancelled))
            return nil
        }

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

    private static func createInteractor(
        signingData: Data,
        metaId: String,
        chainId: ChainModel.Id,
        params: LedgerTxConfirmationParams
    ) -> BaseLedgerTxConfirmInteractor? {
        switch params.walletType {
        case .legacy:
            return createLegacyInteractor(with: signingData, metaId: metaId, chainId: chainId)
        case .generic:
            return createGenericInteractor(
                with: signingData,
                metaId: metaId,
                chainId: chainId,
                params: params
            )
        }
    }

    private static func createGenericInteractor(
        with signingData: Data,
        metaId: String,
        chainId: ChainModel.Id,
        params: LedgerTxConfirmationParams
    ) -> BaseLedgerTxConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId) else {
            return nil
        }

        let ledgerConnection = LedgerConnectionManager(logger: Logger.shared)

        let ledgerApplication = GenericLedgerSubstrateApplication(connectionManager: ledgerConnection)

        let runtimeMetadataFactory = RuntimeMetadataRepositoryFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let proofOperationFactory = ExtrinsicProofOperationFactory(
            metadataRepositoryFactory: runtimeMetadataFactory
        )

        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(for: nil, sortDescriptors: [])

        return GenericLedgerTxConfirmInteractor(
            signingData: signingData,
            metaId: metaId,
            chain: chain,
            extrinsicParams: params,
            ledgerConnection: ledgerConnection,
            ledgerApplication: ledgerApplication,
            chainConnection: connection,
            proofOperationFactory: proofOperationFactory,
            walletRepository: walletRepository,
            signatureVerifier: SignatureVerificationWrapper(),
            keystore: Keychain(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            mortalityPeriodMilliseconds: TimeInterval(MortalEraOperationFactory.mortalPeriod)
        )
    }

    private static func createLegacyInteractor(
        with signingData: Data,
        metaId: String,
        chainId: ChainModel.Id
    ) -> BaseLedgerTxConfirmInteractor {
        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(for: nil, sortDescriptors: [])

        let ledgerConnection = LedgerConnectionManager(logger: Logger.shared)
        let ledgerApplication = LedgerApplication(
            connectionManager: ledgerConnection,
            supportedApps: SupportedLedgerApp.substrate()
        )

        return LedgerTxConfirmInteractor(
            signingData: signingData,
            metaId: metaId,
            chainId: chainId,
            ledgerConnection: ledgerConnection,
            ledgerApplication: ledgerApplication,
            walletRepository: walletRepository,
            signatureVerifier: SignatureVerificationWrapper(),
            keystore: Keychain(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            mortalityPeriodMilliseconds: TimeInterval(MortalEraOperationFactory.mortalPeriod)
        )
    }
}
