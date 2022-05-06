import Foundation
import SubstrateSdk
import RobinHood

final class StorageListSyncService<K: Encodable, U: JSONListConvertible, T: Decodable>: BaseSyncService {
    typealias RemoteResponse = (remoteKey: U, response: StorageResponse<T>)
    typealias LocalResponse = (remoteKey: U, response: T)

    let storagePath: StorageCodingPath
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue
    let key: K
    let chainId: ChainModel.Id

    let completionClosure: (StorageListSyncResult<U, T>) -> Void
    let completionQueue: DispatchQueue

    init(
        key: K,
        chainId: ChainModel.Id,
        storagePath: StorageCodingPath,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        completionQueue: DispatchQueue,
        completionClosure: @escaping (StorageListSyncResult<U, T>) -> Void
    ) {
        self.key = key
        self.chainId = chainId
        self.storagePath = storagePath
        self.repositoryFactory = repositoryFactory
        self.connection = connection
        self.runtimeCodingService = runtimeCodingService
        self.operationQueue = operationQueue
        self.completionQueue = completionQueue
        self.completionClosure = completionClosure
    }

    private func notifyCompletion(for result: StorageListSyncResult<U, T>) {
        completionQueue.async { [weak self] in
            self?.completionClosure(result)
        }
    }

    private func prepareKeyEncodingOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<[Data]> {
        let operation = MapKeyEncodingOperation(
            path: storagePath,
            storageKeyFactory: StorageKeyFactory(),
            keyParams: [key]
        )

        operation.configurationBlock = {
            do {
                operation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                operation.result = .failure(error)
            }
        }

        return operation
    }

    private func prepareLocalKeyOperation(
        dependingOn prefixKeyOperation: BaseOperation<[Data]>,
        chainId: ChainModel.Id
    ) -> BaseOperation<String> {
        ClosureOperation {
            guard let prefixKey = try prefixKeyOperation.extractNoCancellableResultData().first else {
                throw CommonError.dataCorruption
            }

            return try LocalStorageKeyFactory().createRestorableKey(from: prefixKey, chainId: chainId)
        }
    }

    private func prepareLocalFetchOperation(
        dependingOn localKeyOperation: BaseOperation<String>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        storagePath: StorageCodingPath,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<[LocalResponse]> {
        let combinedOperation: BaseOperation<[[LocalStorageResponse<T>]]> = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let localKey = try localKeyOperation.extractNoCancellableResultData()

            let filter = NSPredicate.filterByIdPrefix(localKey)

            let repository = repositoryFactory.createChainStorageItemRepository(filter: filter)

            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let wrapper: CompoundOperationWrapper<[LocalStorageResponse<T>]> =
                LocalStorageRequestFactory().queryItemList(
                    repository: repository,
                    factory: { codingFactory },
                    params: StorageRequestParams(path: storagePath)
                )

            return [wrapper]
        }.longrunOperation()

        let decodingKeysOperation = StorageKeyDecodingOperation<U>(
            path: storagePath
        )

        decodingKeysOperation.configurationBlock = {
            do {
                decodingKeysOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()

                let localItems = try combinedOperation.extractNoCancellableResultData().flatMap { $0 }
                let keyFactory = LocalStorageKeyFactory()

                decodingKeysOperation.dataList = try localItems.map {
                    try keyFactory.restoreRemoteKey(from: $0.key, chainId: chainId)
                }

            } catch {
                decodingKeysOperation.result = .failure(error)
            }
        }

        decodingKeysOperation.addDependency(combinedOperation)

        let mapOperation = ClosureOperation<[LocalResponse]> {
            let localItems = try combinedOperation.extractNoCancellableResultData().flatMap { $0 }
            let remoteKeys = try decodingKeysOperation.extractNoCancellableResultData()

            return zip(localItems, remoteKeys).compactMap { result in
                guard let value = result.0.value else {
                    return nil
                }

                return LocalResponse(remoteKey: result.1, response: value)
            }
        }

        mapOperation.addDependency(decodingKeysOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [combinedOperation, decodingKeysOperation]
        )
    }

    private func prepareRemoteFetchWrapper(
        for prefixKey: Data,
        storagePath: StorageCodingPath,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[RemoteResponse]> {
        let operationManager = OperationManager(operationQueue: operationQueue)
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let keysFetchOperation = StorageKeysQueryService(
            connection: connection,
            operationManager: operationManager,
            prefixKeyClosure: { prefixKey },
            mapper: AnyMapper(mapper: IdentityMapper())
        ).longrunOperation()

        let keysDecodingOperation = StorageKeyDecodingOperation<U>(
            path: storagePath,
            codingFactory: codingFactory
        )

        keysDecodingOperation.configurationBlock = {
            do {
                keysDecodingOperation.dataList = try keysFetchOperation.extractNoCancellableResultData()
            } catch {
                keysDecodingOperation.result = .failure(error)
            }
        }

        keysDecodingOperation.addDependency(keysFetchOperation)

        let remoteFetchWrapper: CompoundOperationWrapper<[StorageResponse<T>]> =
            requestFactory.queryItems(
                engine: connection,
                keys: {
                    try keysFetchOperation.extractNoCancellableResultData()
                }, factory: { codingFactory },
                storagePath: storagePath
            )

        remoteFetchWrapper.addDependency(operations: [keysFetchOperation])

        let mapOperation: BaseOperation<[RemoteResponse]> = ClosureOperation {
            let remoteKeys = try keysDecodingOperation.extractNoCancellableResultData()
            let remoteItems = try remoteFetchWrapper.targetOperation.extractNoCancellableResultData()

            return zip(remoteKeys, remoteItems).map { RemoteResponse(remoteKey: $0.0, response: $0.1) }
        }

        mapOperation.addDependency(keysDecodingOperation)
        mapOperation.addDependency(remoteFetchWrapper.targetOperation)

        let dependencies = [keysFetchOperation] + remoteFetchWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func fetchRemote(
        for prefixKey: Data,
        storagePath: StorageCodingPath,
        chainId: ChainModel.Id,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws {
        let remoteFetchWrapper = prepareRemoteFetchWrapper(
            for: prefixKey,
            storagePath: storagePath,
            codingFactory: codingFactory
        )

        let localStorateKeyFactory = LocalStorageKeyFactory()
        let baseLocalKey = try localStorateKeyFactory.createFromStoragePath(
            storagePath,
            chainId: chainId
        )

        let filter = NSPredicate.filterByIdPrefix(baseLocalKey)
        let repository = repositoryFactory.createChainStorageItemRepository(filter: filter)

        let replaceOperation = repository.replaceOperation {
            let remoteItems = try remoteFetchWrapper.targetOperation.extractNoCancellableResultData()

            return try remoteItems.compactMap { remoteItem in
                guard let data = remoteItem.response.data else {
                    return nil
                }

                let localKey = try localStorateKeyFactory.createKey(
                    from: remoteItem.response.key,
                    chainId: chainId
                )

                return ChainStorageItem(identifier: localKey, data: data)
            }
        }

        replaceOperation.addDependency(remoteFetchWrapper.targetOperation)

        replaceOperation.completionBlock = { [weak self] in
            do {
                let remoteItems = try remoteFetchWrapper.targetOperation.extractNoCancellableResultData()

                let mappedItems: [StorageListSyncResult<U, T>.Item] = remoteItems.compactMap { remoteItem in
                    guard let value = remoteItem.response.value else {
                        return nil
                    }

                    return StorageListSyncResult.Item(key: remoteItem.remoteKey, value: value)
                }

                self?.notifyCompletion(for: StorageListSyncResult(items: mappedItems))
                self?.complete(nil)
            } catch {
                self?.complete(error)
            }
        }

        let operations = remoteFetchWrapper.allOperations + [replaceOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func fetchLocalAndUpdateIfNeeded(for chainId: ChainModel.Id, storagePath: StorageCodingPath) {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        let encodingOperation = prepareKeyEncodingOperation(dependingOn: codingFactoryOperation)

        encodingOperation.addDependency(codingFactoryOperation)

        let localKeyOperation = prepareLocalKeyOperation(
            dependingOn: encodingOperation,
            chainId: chainId
        )

        localKeyOperation.addDependency(encodingOperation)

        let localFetchWrapper = prepareLocalFetchOperation(
            dependingOn: localKeyOperation,
            codingFactoryOperation: codingFactoryOperation,
            repositoryFactory: repositoryFactory,
            storagePath: storagePath,
            chainId: chainId
        )

        localFetchWrapper.addDependency(operations: [localKeyOperation, codingFactoryOperation])

        localFetchWrapper.targetOperation.completionBlock = { [weak self] in
            do {
                let localItems = try localFetchWrapper.targetOperation.extractNoCancellableResultData()

                if !localItems.isEmpty {
                    let resulItems = localItems.map { localItem in
                        StorageListSyncResult.Item(key: localItem.remoteKey, value: localItem.response)
                    }
                    self?.notifyCompletion(for: StorageListSyncResult(items: resulItems))
                    self?.complete(nil)
                } else {
                    guard let prefixKey = try encodingOperation.extractNoCancellableResultData().first else {
                        throw CommonError.dataCorruption
                    }

                    let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                    try self?.fetchRemote(
                        for: prefixKey,
                        storagePath: storagePath,
                        chainId: chainId,
                        codingFactory: codingFactory
                    )
                }
            } catch {
                self?.complete(error)
            }
        }

        let operations = [codingFactoryOperation, encodingOperation, localKeyOperation] +
            localFetchWrapper.allOperations

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    override func performSyncUp() {
        fetchLocalAndUpdateIfNeeded(for: chainId, storagePath: storagePath)
    }

    override func stopSyncUp() {
        operationQueue.cancelAllOperations()
    }
}
