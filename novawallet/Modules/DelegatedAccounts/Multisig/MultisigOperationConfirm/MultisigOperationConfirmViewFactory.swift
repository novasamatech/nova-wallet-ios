import Foundation
import Operation_iOS

struct MultisigOperationConfirmViewFactory {
    static func createView(for operation: Multisig.PendingOperation) -> MultisigOperationConfirmViewProtocol? {
        guard
            let chain = ChainRegistryFacade.sharedRegistry.getChain(for: operation.chainId),
            let interactor = createInteractor(for: operation, chain: chain) else {
            return nil
        }

        let wireframe = MultisigOperationConfirmWireframe()

        let presenter = MultisigOperationConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            logger: Logger.shared
        )

        let view = MultisigOperationConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for operation: Multisig.PendingOperation,
        chain: ChainModel
    ) -> MultisigOperationConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let multisigWallet = SelectedWalletSettings.shared.value,
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        )

        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(for: nil, sortDescriptors: [])

        return MultisigOperationConfirmInteractor(
            operation: operation,
            chain: chain,
            multisigWallet: multisigWallet,
            signatoryRepository: MultisigSignatoryRepository(repository: walletRepository),
            pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactory.shared,
            extrinsicServiceFactory: extrinsicServiceFactory,
            signingWrapperFactory: SigningWrapperFactory(),
            chainRegistry: chainRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
