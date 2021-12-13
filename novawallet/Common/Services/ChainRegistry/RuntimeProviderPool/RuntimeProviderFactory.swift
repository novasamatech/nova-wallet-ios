import Foundation
import RobinHood

protocol RuntimeProviderFactoryProtocol {
    func createRuntimeProvider(for chain: ChainModel) -> RuntimeProviderProtocol
}

final class RuntimeProviderFactory {
    let fileOperationFactory: RuntimeFilesOperationFactoryProtocol
    let repository: AnyDataProviderRepository<RuntimeMetadataItem>
    let dataOperationFactory: DataOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?

    init(
        fileOperationFactory: RuntimeFilesOperationFactoryProtocol,
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        dataOperationFactory: DataOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.fileOperationFactory = fileOperationFactory
        self.repository = repository
        self.dataOperationFactory = dataOperationFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension RuntimeProviderFactory: RuntimeProviderFactoryProtocol {
    func createRuntimeProvider(for chain: ChainModel) -> RuntimeProviderProtocol {
        let accountIdLength: Int = {
            switch chain.chainFormat {
            case .substrate:
                return 32
            case .ethereum:
                return 20
            }
        }()

        let snapshotOperationFactory = RuntimeSnapshotFactory(
            chainId: chain.chainId,
            accountIdLength: accountIdLength,
            filesOperationFactory: fileOperationFactory,
            repository: repository
        )

        return RuntimeProvider(
            chainModel: chain,
            snapshotOperationFactory: snapshotOperationFactory,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
