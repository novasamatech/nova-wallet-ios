import Foundation
import Operation_iOS

protocol GovernanceServiceFactoryProtocol {
    func createBlockTimeService(for chainId: ChainModel.Id) throws -> BlockTimeEstimationServiceProtocol
}

final class GovernanceServiceFactory: GovernanceServiceFactoryProtocol {
    let blockTimeServiceFactory: BlockTimeEstimationServiceFactoryProtocol

    init(
        chainRegisty: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        blockTimeServiceFactory = BlockTimeEstimationServiceFactory(
            chainRegisty: chainRegisty,
            storageFacade: storageFacade,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    func createBlockTimeService(for chainId: ChainModel.Id) throws -> BlockTimeEstimationServiceProtocol {
        try blockTimeServiceFactory.createService(for: chainId)
    }
}
