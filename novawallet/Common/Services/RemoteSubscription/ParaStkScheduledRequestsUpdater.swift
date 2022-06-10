import Foundation
import RobinHood
import SubstrateSdk

final class ParaStkScheduledRequestsUpdater: BaseStorageChildSubscription {
    let chainRegistry: ChainRegistryProtocol
    let accountId: AccountId
    let chainId: ChainModel.Id
    let storageRequestFactory: StorageRequestFactoryProtocol

    private lazy var localKeyFactory = LocalStorageKeyFactory()

    init(
        remoteStorageKey: Data,
        localStorageKey: String,
        chainRegistry: ChainRegistryProtocol,
        delegatorStorage: AnyDataProviderRepository<ChainStorageItem>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        operationManager: OperationManagerProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.accountId = accountId
        self.chainId = chainId
        self.storageRequestFactory = storageRequestFactory

        super.init(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: delegatorStorage,
            operationManager: operationManager,
            logger: logger
        )
    }

    private func createUpdateOperation(
        for requestsClosure: @escaping () throws -> [ParachainStaking.DelegatorScheduledRequest],
        localKey: String
    ) -> BaseOperation<Void> {
        storage.saveOperation({
            let requests = try requestsClosure()

            if !requests.isEmpty {
                let data = try JSONEncoder().encode(requests)
                return [ChainStorageItem(identifier: localKey, data: data)]
            } else {
                return []
            }
        }, {
            let requests = try requestsClosure()
            if requests.isEmpty {
                return [localKey]
            } else {
                return []
            }
        })
    }

    private func createMappingOperation(
        for collatorsClosure: @escaping () throws -> [AccountId],
        requestResponsesClosure: @escaping () throws -> [StorageResponse<[ParachainStaking.ScheduledRequest]>],
        delegatorId: AccountId
    ) -> BaseOperation<[ParachainStaking.DelegatorScheduledRequest]> {
        ClosureOperation<[ParachainStaking.DelegatorScheduledRequest]> {
            let collators = try collatorsClosure()
            let responses = try requestResponsesClosure()

            return zip(collators, responses).compactMap { collator, response in
                guard
                    let scheduledRequests = response.value,
                    let delegationRequest = scheduledRequests.first(where: { $0.delegator == delegatorId }) else {
                    return nil
                }

                return ParachainStaking.DelegatorScheduledRequest(
                    collatorId: collator,
                    whenExecutable: delegationRequest.whenExecutable,
                    action: delegationRequest.action
                )
            }
        }
    }

    private func createDecodingOperation(
        for data: Data,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<ParachainStaking.Delegator> {
        let decodingOperation = StorageDecodingOperation<ParachainStaking.Delegator>(
            path: ParachainStaking.delegatorStatePath,
            data: data
        )

        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        return decodingOperation
    }

    private func createRemoteFetchWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        decodingOperation: BaseOperation<ParachainStaking.Delegator>,
        connection: JSONRPCEngine,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<[ParachainStaking.ScheduledRequest]>]> {
        let keyParams: () throws -> [BytesCodable] = {
            let delegator = try decodingOperation.extractNoCancellableResultData()
            return delegator.collators().map { BytesCodable(wrappedValue: $0) }
        }

        return storageRequestFactory.queryItems(
            engine: connection,
            keyParams: keyParams,
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: ParachainStaking.delegationRequestsPath,
            at: blockHash
        )
    }

    private func createLocalKey() -> String? {
        try? localKeyFactory.createRestorableRecurrentKey(
            from: ParachainStaking.delegationRequestsPath,
            chainId: chainId,
            items: [accountId]
        )
    }

    override func handle(
        result _: Result<DataProviderChange<ChainStorageItem>?, Error>,
        remoteItem: ChainStorageItem?,
        blockHash: Data?
    ) {
        process(data: remoteItem?.data, blockHash: blockHash)
    }
}

extension ParaStkScheduledRequestsUpdater {
    func process(data: Data?, blockHash: Data?) {
        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId),
            let localKey = createLocalKey() else {
            logger.error("Unexpected error during preparation")
            return
        }

        let wrapper: CompoundOperationWrapper<Void>

        if let data = data {
            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let decodingOperation = createDecodingOperation(for: data, dependingOn: codingFactoryOperation)

            decodingOperation.addDependency(codingFactoryOperation)

            let remoteFetchWrapper = createRemoteFetchWrapper(
                dependingOn: codingFactoryOperation,
                decodingOperation: decodingOperation,
                connection: connection,
                blockHash: blockHash
            )

            remoteFetchWrapper.addDependency(operations: [decodingOperation])

            let mapOperation = createMappingOperation(
                for: { try decodingOperation.extractNoCancellableResultData().collators() },
                requestResponsesClosure: { try remoteFetchWrapper.targetOperation.extractNoCancellableResultData() },
                delegatorId: accountId
            )

            mapOperation.addDependency(remoteFetchWrapper.targetOperation)

            let replaceOperation = createUpdateOperation(
                for: { try mapOperation.extractNoCancellableResultData() },
                localKey: localKey
            )

            replaceOperation.addDependency(mapOperation)

            let dependencies = [codingFactoryOperation, decodingOperation] + remoteFetchWrapper.allOperations +
                [mapOperation]

            wrapper = CompoundOperationWrapper(targetOperation: replaceOperation, dependencies: dependencies)
        } else {
            let replaceOperation = createUpdateOperation(
                for: { [] },
                localKey: localKey
            )

            wrapper = CompoundOperationWrapper(targetOperation: replaceOperation)
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }
}
