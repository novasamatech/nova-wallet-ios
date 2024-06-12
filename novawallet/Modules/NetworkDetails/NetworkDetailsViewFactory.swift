import SoraFoundation
import Operation_iOS

struct NetworkDetailsViewFactory {
    static func createView(with chain: ChainModel) -> NetworkDetailsViewProtocol? {
        let connectionFactory = ConnectionFactory(
            logger: Logger.shared,
            operationQueue: OperationManagerFacade.assetsSyncQueue
        )

        let chainRegistry = ChainRegistryFactory.createDefaultRegistry()

        let repository = SubstrateRepositoryFactory().createChainRepository()

        let interactor = NetworkDetailsInteractor(
            chain: chain,
            connectionFactory: connectionFactory,
            chainRegistry: chainRegistry,
            repository: repository,
            operationQueue: OperationManagerFacade.assetsRepositoryQueue,
            nodeMeasureQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let wireframe = NetworkDetailsWireframe()

        let viewModelFactory = NetworkDetailsViewModelFactory(
            localizationManager: LocalizationManager.shared,
            networkViewModelFactory: NetworkViewModelFactory()
        )

        let presenter = NetworkDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            viewModelFactory: viewModelFactory
        )

        let view = NetworkDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
