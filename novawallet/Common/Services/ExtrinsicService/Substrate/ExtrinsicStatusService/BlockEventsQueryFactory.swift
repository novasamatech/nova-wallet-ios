import Foundation
import Operation_iOS
import SubstrateSdk

protocol BlockEventsQueryFactoryProtocol {
    func queryExtrinsicEventsWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data
    ) -> CompoundOperationWrapper<[SubstrateExtrinsicEvents]>

    func queryInherentEventsWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data
    ) -> CompoundOperationWrapper<SubstrateInherentsEvents>
}

final class BlockEventsQueryFactory {
    let storageRequestFactory: StorageRequestFactoryProtocol
    let eventsRepository: SubstrateEventsRepositoryProtocol
    let logger: LoggerProtocol

    init(
        operationQueue: OperationQueue,
        eventsRepository: SubstrateEventsRepositoryProtocol = SubstrateEventsRepository(),
        logger: LoggerProtocol = Logger.shared
    ) {
        storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        self.eventsRepository = eventsRepository

        self.logger = logger
    }

    private func createEventsWrapper(
        dependingOn coderFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        connection: JSONRPCEngine,
        blockHash: Data
    ) -> CompoundOperationWrapper<StorageResponse<[EventRecord]>> {
        storageRequestFactory.queryItem(
            engine: connection,
            factory: {
                try coderFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: SystemPallet.eventsPath,
            at: blockHash
        )
    }

    private func createBlockFetchOperation(
        for connection: JSONRPCEngine,
        blockHash: Data
    ) -> JSONRPCOperation<[String], SignedBlock> {
        JSONRPCOperation(
            engine: connection,
            method: RPCMethod.getChainBlock,
            parameters: [blockHash.toHex(includePrefix: true)]
        )
    }

    private func createParsingExtrinsicEventsOperation(
        dependingOn eventsOperation: BaseOperation<StorageResponse<[EventRecord]>>,
        blockOperation: BaseOperation<SignedBlock>,
        repository: SubstrateEventsRepositoryProtocol,
        logger: LoggerProtocol
    ) -> BaseOperation<[SubstrateExtrinsicEvents]> {
        ClosureOperation {
            let block = try blockOperation.extractNoCancellableResultData().block

            logger.debug("Block received: \(block)")

            let eventRecords = try eventsOperation.extractNoCancellableResultData().value ?? []

            logger.debug("Events received: \(eventRecords)")

            return repository.getExtrinsicsEvents(from: block, eventRecords: eventRecords)
        }
    }

    private func createParsingInherentEventsOperation(
        dependingOn eventsOperation: BaseOperation<StorageResponse<[EventRecord]>>,
        repository: SubstrateEventsRepositoryProtocol,
        logger: LoggerProtocol
    ) -> BaseOperation<SubstrateInherentsEvents> {
        ClosureOperation {
            let eventRecords = try eventsOperation.extractNoCancellableResultData().value ?? []

            logger.debug("Events received: \(eventRecords)")

            return repository.getInherentEvents(from: eventRecords)
        }
    }
}

extension BlockEventsQueryFactory: BlockEventsQueryFactoryProtocol {
    func queryExtrinsicEventsWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data
    ) -> CompoundOperationWrapper<[SubstrateExtrinsicEvents]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let eventsWrapper = createEventsWrapper(
            dependingOn: codingFactoryOperation,
            connection: connection,
            blockHash: blockHash
        )

        eventsWrapper.addDependency(operations: [codingFactoryOperation])

        let blockFetchOperation = createBlockFetchOperation(
            for: connection,
            blockHash: blockHash
        )

        let parsingOperation = createParsingExtrinsicEventsOperation(
            dependingOn: eventsWrapper.targetOperation,
            blockOperation: blockFetchOperation,
            repository: eventsRepository,
            logger: logger
        )

        parsingOperation.addDependency(eventsWrapper.targetOperation)
        parsingOperation.addDependency(blockFetchOperation)

        return eventsWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: blockFetchOperation)
            .insertingTail(operation: parsingOperation)
    }

    func queryInherentEventsWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data
    ) -> CompoundOperationWrapper<SubstrateInherentsEvents> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let eventsWrapper = createEventsWrapper(
            dependingOn: codingFactoryOperation,
            connection: connection,
            blockHash: blockHash
        )

        let parsingOperation = createParsingInherentEventsOperation(
            dependingOn: eventsWrapper.targetOperation,
            repository: eventsRepository,
            logger: logger
        )

        parsingOperation.addDependency(eventsWrapper.targetOperation)

        return eventsWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: parsingOperation)
    }
}
