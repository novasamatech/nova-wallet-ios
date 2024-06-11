import SoraFoundation
import RobinHood

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

        let viewModelFactory = NetworkDetailsViewModelFactory(localizationManager: LocalizationManager.shared)

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

    // swiftlint:enable function_body_length

    private static func createFilesOperationFactory() -> RuntimeFilesOperationFactoryProtocol {
        let topDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
        let runtimeDirectory = topDirectory.appendingPathComponent("runtime").path
        return RuntimeFilesOperationFactory(
            repository: FileRepository(),
            directoryPath: runtimeDirectory
        )
    }

    private static func createChainProvider(
        from repositoryFacade: StorageFacadeProtocol,
        chainRepository: CoreDataRepository<ChainModel, CDChain>
    ) -> StreamableProvider<ChainModel> {
        let chainObserver = CoreDataContextObservable(
            service: repositoryFacade.databaseService,
            mapper: chainRepository.dataMapper,
            predicate: { _ in true }
        )

        chainObserver.start { error in
            if let error = error {
                Logger.shared.error("Chain database observer unexpectedly failed: \(error)")
            }
        }

        return StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource<ChainModel>()),
            repository: AnyDataProviderRepository(chainRepository),
            observable: AnyDataProviderRepositoryObservable(chainObserver),
            operationManager: OperationManagerFacade.sharedManager
        )
    }
}
