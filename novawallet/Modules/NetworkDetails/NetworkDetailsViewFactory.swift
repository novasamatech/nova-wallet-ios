import SoraFoundation
import RobinHood

struct NetworkDetailsViewFactory {
    static func createView(with chain: ChainModel) -> NetworkDetailsViewProtocol? {
        let connectionFactory = ConnectionFactory(
            logger: Logger.shared,
            operationQueue: OperationManagerFacade.assetsSyncQueue
        )

        let repositoryFacade = SubstrateDataStorageFacade.shared

        let runtimeMetadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            repositoryFacade.createRepository()

        let dataFetchOperationFactory = DataOperationFactory()

        let filesOperationFactory = createFilesOperationFactory()

        let runtimeSyncService = RuntimeSyncService(
            repository: AnyDataProviderRepository(runtimeMetadataRepository),
            filesOperationFactory: filesOperationFactory,
            dataOperationFactory: dataFetchOperationFactory,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.runtimeSyncQueue,
            logger: Logger.shared
        )

        let runtimeProviderFactory = RuntimeProviderFactory(
            fileOperationFactory: filesOperationFactory,
            repository: AnyDataProviderRepository(runtimeMetadataRepository),
            dataOperationFactory: dataFetchOperationFactory,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.runtimeBuildingQueue,
            logger: Logger.shared
        )

        let runtimeProviderPool = RuntimeProviderPool(runtimeProviderFactory: runtimeProviderFactory)

        let connectionPool = ConnectionPool(
            connectionFactory: connectionFactory,
            applicationHandler: SecurityLayerService.shared.applicationHandlingProxy.addApplicationHandler()
        )

        let mapper = ChainModelMapper()
        let chainRepository: CoreDataRepository<ChainModel, CDChain> =
            repositoryFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let chainProvider = createChainProvider(from: repositoryFacade, chainRepository: chainRepository)

        let chainSyncService = ChainSyncService(
            url: ApplicationConfig.shared.chainListURL,
            evmAssetsURL: ApplicationConfig.shared.evmAssetsURL,
            chainConverter: ChainModelConverter(),
            dataFetchFactory: dataFetchOperationFactory,
            repository: AnyDataProviderRepository(chainRepository),
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.runtimeSyncQueue,
            logger: Logger.shared
        )

        let specVersionSubscriptionFactory = SpecVersionSubscriptionFactory(
            runtimeSyncService: runtimeSyncService,
            logger: Logger.shared
        )

        let commonTypesSyncService = CommonTypesSyncService(
            url: ApplicationConfig.shared.commonTypesURL,
            filesOperationFactory: filesOperationFactory,
            dataOperationFactory: dataFetchOperationFactory,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.runtimeSyncQueue
        )

        let chainRegistry = ChainRegistry(
            runtimeProviderPool: runtimeProviderPool,
            connectionPool: connectionPool,
            chainSyncService: chainSyncService,
            runtimeSyncService: runtimeSyncService,
            commonTypesSyncService: commonTypesSyncService,
            chainProvider: chainProvider,
            specVersionSubscriptionFactory: specVersionSubscriptionFactory,
            logger: Logger.shared
        )

        let repository = SubstrateRepositoryFactory().createChainRepository()

        let interactor = NetworkDetailsInteractor(
            chain: chain,
            connectionFactory: connectionFactory,
            chainRegistry: chainRegistry,
            chainSyncService: chainSyncService,
            repository: repository,
            operationQueue: OperationManagerFacade.assetsRepositoryQueue
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
