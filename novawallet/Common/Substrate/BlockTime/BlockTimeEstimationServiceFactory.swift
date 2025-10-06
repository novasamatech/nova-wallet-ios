import Foundation

protocol BlockTimeEstimationServiceFactoryProtocol {
    func createService(for chainId: ChainModel.Id) throws -> BlockTimeEstimationServiceProtocol
}

final class BlockTimeEstimationServiceFactory {
    let chainRegisty: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chainRegisty: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegisty = chainRegisty
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension BlockTimeEstimationServiceFactory: BlockTimeEstimationServiceFactoryProtocol {
    func createService(for chainId: ChainModel.Id) throws -> BlockTimeEstimationServiceProtocol {
        let runtimeService = try chainRegisty.getRuntimeProviderOrError(for: chainId)
        let connection = try chainRegisty.getConnectionOrError(for: chainId)

        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)

        let repository = repositoryFactory.createChainStorageItemRepository()

        return BlockTimeEstimationService(
            chainId: chainId,
            connection: connection,
            runtimeService: runtimeService,
            repository: repository,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
