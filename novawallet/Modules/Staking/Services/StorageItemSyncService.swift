import Foundation
import SubstrateSdk
import RobinHood

final class StorageItemSyncService<T: Decodable>: BaseSyncService {
    let storagePath: StorageCodingPath
    let repository: AnyDataProviderRepository<ChainStorageItem>
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue
    let chainId: ChainModel.Id

    let completionClosure: (T?) -> Void
    let completionQueue: DispatchQueue

    let request: SubscriptionRequestProtocol

    init(
        chainId: ChainModel.Id,
        storagePath: StorageCodingPath,
        request: SubscriptionRequestProtocol,
        repository: AnyDataProviderRepository<ChainStorageItem>,
        connection: JSONRPCEngine,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol,
        completionQueue: DispatchQueue,
        completionClosure: @escaping (T?) -> Void
    ) {
        self.chainId = chainId
        self.storagePath = storagePath
        self.request = request
        self.repository = repository
        self.connection = connection
        self.runtimeCodingService = runtimeCodingService
        self.operationQueue = operationQueue
        self.completionQueue = completionQueue
        self.completionClosure = completionClosure

        super.init(retryStrategy: ExponentialReconnection(), logger: logger)
    }

    override func performSyncUp() {
        fetchLocalAndUpdateIfNeeded(for: chainId, storagePath: storagePath)
    }

    override func stopSyncUp() {
        operationQueue.cancelAllOperations()
    }
}

extension StorageItemSyncService {
    private func notifyCompletion(for result: T?) {
        completionQueue.async { [weak self] in
            self?.completionClosure(result)
        }
    }

    private func prepareLocalFetchOperation(
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        storagePath: StorageCodingPath,
        chainId _: ChainModel.Id
    ) -> CompoundOperationWrapper<T?> {
        let fetchOperation = repository.fetchOperation(
            by: request.localKey,
            options: RepositoryFetchOptions()
        )

        let decodingOperation = StorageDecodingOperation<T?>(path: storagePath)

        decodingOperation.configurationBlock = {
            do {
                if let data = try fetchOperation.extractNoCancellableResultData()?.data {
                    decodingOperation.data = data
                    decodingOperation.codingFactory = try codingFactoryOperation
                        .extractNoCancellableResultData()
                } else {
                    decodingOperation.result = .success(nil)
                }

            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: decodingOperation,
            dependencies: [fetchOperation]
        )
    }

    private func prepareRemoteFetchWrapper(
        for remoteKey: Data,
        storagePath: StorageCodingPath,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<StorageResponse<T>?> {
        let operationManager = OperationManager(operationQueue: operationQueue)
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let remoteFetchWrapper: CompoundOperationWrapper<[StorageResponse<T>]> =
            requestFactory.queryItems(
                engine: connection,
                keys: { [remoteKey] },
                factory: { codingFactory },
                storagePath: storagePath
            )

        let mapOperation: BaseOperation<StorageResponse<T>?> = ClosureOperation {
            try remoteFetchWrapper.targetOperation.extractNoCancellableResultData().first
        }

        mapOperation.addDependency(remoteFetchWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: remoteFetchWrapper.allOperations
        )
    }

    private func fetchRemote(
        for remoteKey: Data,
        storagePath: StorageCodingPath,
        chainId _: ChainModel.Id,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws {
        let remoteFetchWrapper = prepareRemoteFetchWrapper(
            for: remoteKey,
            storagePath: storagePath,
            codingFactory: codingFactory
        )

        let localKey = request.localKey

        let replaceOperation = repository.saveOperation({
            if
                let remoteItem = try remoteFetchWrapper.targetOperation
                .extractNoCancellableResultData(),
                let data = remoteItem.data {
                let localItem = ChainStorageItem(identifier: localKey, data: data)
                return [localItem]
            } else {
                return []
            }
        }, { [] })

        replaceOperation.addDependency(remoteFetchWrapper.targetOperation)

        replaceOperation.completionBlock = { [weak self] in
            do {
                let remoteItem = try remoteFetchWrapper.targetOperation.extractNoCancellableResultData()?.value

                self?.notifyCompletion(for: remoteItem)
                self?.complete(nil)
            } catch {
                self?.complete(error)
            }
        }

        let operations = remoteFetchWrapper.allOperations + [replaceOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func fetchLocalAndUpdateIfNeeded(
        for chainId: ChainModel.Id,
        storagePath: StorageCodingPath
    ) {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        let encodingWrapper = request.createKeyEncodingWrapper(
            using: StorageKeyFactory(),
            codingFactoryClosure: {
                try codingFactoryOperation.extractNoCancellableResultData()
            }
        )

        encodingWrapper.addDependency(operations: [codingFactoryOperation])

        let localFetchWrapper = prepareLocalFetchOperation(
            codingFactoryOperation: codingFactoryOperation,
            storagePath: storagePath,
            chainId: chainId
        )

        localFetchWrapper.addDependency(operations: [codingFactoryOperation])

        localFetchWrapper.targetOperation.completionBlock = { [weak self] in
            do {
                let localItem = try localFetchWrapper.targetOperation.extractNoCancellableResultData()

                if localItem != nil {
                    self?.notifyCompletion(for: localItem)
                    self?.complete(nil)
                } else {
                    let remoteKey = try encodingWrapper.targetOperation
                        .extractNoCancellableResultData()

                    let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                    try self?.fetchRemote(
                        for: remoteKey,
                        storagePath: storagePath,
                        chainId: chainId,
                        codingFactory: codingFactory
                    )
                }
            } catch {
                self?.complete(error)
            }
        }

        let operations = [codingFactoryOperation] + encodingWrapper.allOperations +
            localFetchWrapper.allOperations

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }
}
