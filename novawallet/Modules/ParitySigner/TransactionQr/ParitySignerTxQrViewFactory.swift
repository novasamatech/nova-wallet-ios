import Foundation
import Foundation_iOS

struct ParitySignerTxQrViewFactory {
    static func createView(
        with signingData: Data,
        metaId: String,
        chainId: ChainModel.Id,
        type: ParitySignerType,
        completion: @escaping TransactionSigningClosure
    ) -> ParitySignerTxQrViewProtocol? {
        guard let interactor = createInteractor(from: signingData, metaId: metaId, chainId: chainId) else {
            return nil
        }

        let wireframe = ParitySignerTxQrWireframe(sharedSigningPayload: signingData)

        let presenter = ParitySignerTxQrPresenter(
            type: type,
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
            type: type,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        from signingData: Data,
        metaId: String,
        chainId: ChainModel.Id
    ) -> ParitySignerTxQrInteractor? {
        let repositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let walletRepository = repositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        return ParitySignerTxQrInteractor(
            signingData: signingData,
            metaId: metaId,
            chainId: chainId,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletRepository: walletRepository,
            messageOperationFactory: ParitySignerMessageOperationFactory(),
            multipartQrOperationFactory: MultipartQrOperationFactory(),
            mortalityPeriodMilliseconds: TimeInterval(MortalEraOperationFactory.mortalPeriod),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
