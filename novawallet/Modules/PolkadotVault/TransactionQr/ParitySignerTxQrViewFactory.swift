import Foundation
import Foundation_iOS

struct ParitySignerTxQrViewFactory {
    static func createView(
        with signingData: Data,
        metaId: String,
        chainId: ChainModel.Id,
        params: ParitySignerConfirmationParams,
        completion: @escaping TransactionSigningClosure
    ) -> ParitySignerTxQrViewProtocol? {
        guard let interactor = createInteractor(
            from: signingData,
            metaId: metaId,
            chainId: chainId,
            params: params
        ) else {
            return nil
        }

        let wireframe = ParitySignerTxQrWireframe(params: params, sharedSigningPayload: signingData)

        let presenter = ParitySignerTxQrPresenter(
            type: params.type,
            interactor: interactor,
            wireframe: wireframe,
            completion: completion,
            expirationViewModelFactory: TxExpirationViewModelFactory(),
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared,
            localizationManager: LocalizationManager.shared
        )

        let view = ParitySignerTxQrViewController(
            presenter: presenter,
            type: params.type,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        from signingData: Data,
        metaId: String,
        chainId: ChainModel.Id,
        params: ParitySignerConfirmationParams
    ) -> ParitySignerTxQrInteractor? {
        let repositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let walletRepository = repositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let runtimeMetadataFactory = RuntimeMetadataRepositoryFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let proofOperationFactory = ExtrinsicProofOperationFactory(
            metadataRepositoryFactory: runtimeMetadataFactory
        )

        return ParitySignerTxQrInteractor(
            signingData: signingData,
            params: params,
            metaId: metaId,
            chainId: chainId,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletRepository: walletRepository,
            messageOperationFactory: ParitySignerMessageOperationFactory(),
            proofOperationFactory: proofOperationFactory,
            multipartQrOperationFactory: MultipartQrOperationFactory(),
            mortalityPeriodMilliseconds: TimeInterval(MortalEraOperationFactory.mortalPeriod),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
