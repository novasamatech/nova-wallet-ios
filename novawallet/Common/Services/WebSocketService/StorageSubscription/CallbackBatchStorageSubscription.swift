import Foundation
import SubstrateSdk
import RobinHood

final class CallbackBatchStorageSubscription<T: BatchStorageSubscriptionResult> {
    let requests: [BatchStorageSubscriptionRequest]
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue
    let repository: AnyDataProviderRepository<ChainStorageItem>?

    let callbackQueue: DispatchQueue
    let callbackClosure: (Result<T, Error>) -> Void

    private var subscriptionId: UInt16?

    private weak var previousOperation: Operation?
    private var encondingOperations: [Operation]?

    private var mutex = NSLock()

    init(
        requests: [BatchStorageSubscriptionRequest],
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        repository: AnyDataProviderRepository<ChainStorageItem>?,
        operationQueue: OperationQueue,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping (Result<T, Error>) -> Void
    ) {
        self.requests = requests
        self.connection = connection
        self.runtimeService = runtimeService
        self.repository = repository
        self.operationQueue = operationQueue
        self.callbackQueue = callbackQueue
        self.callbackClosure = callbackClosure
    }

    func subscribe() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let keyEncondingWrappers = requests.map { request in
            request.innerRequest.createKeyEncodingWrapper(
                using: StorageKeyFactory(),
                codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() }
            )
        }

        keyEncondingWrappers.forEach { $0.addDependency(operations: [codingFactoryOperation]) }

        let mergeOperation = ClosureOperation<[Data]> {
            try keyEncondingWrappers.map { try $0.targetOperation.extractNoCancellableResultData() }
        }

        mergeOperation.completionBlock = { [weak self] in
            do {
                let keys = try mergeOperation.extractNoCancellableResultData()
                self?.subscribeForEncoded(keys: keys)
            } catch {
                self?.notify(result: .failure(error))
            }
        }

        keyEncondingWrappers.forEach { mergeOperation.addDependency($0.targetOperation) }

        let keysOperations = keyEncondingWrappers.flatMap(\.allOperations)
        let encondingOperations = [codingFactoryOperation] + keysOperations + [mergeOperation]
        self.encondingOperations = encondingOperations

        operationQueue.addOperations(
            encondingOperations,
            waitUntilFinished: false
        )
    }

    private func subscribeForEncoded(keys: [Data]) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard encondingOperations != nil else {
            return
        }

        encondingOperations = nil

        do {
            let updateClosure: (StorageSubscriptionUpdate) -> Void = { [weak self] update in
                let updateData = StorageUpdateData(update: update.params.result)
                self?.processUpdate(
                    updateData.getChangesOrdered(by: keys),
                    keys: keys,
                    blockHash: updateData.blockHash
                )
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, _ in
                self?.notify(result: .failure(error))
            }

            let storageKeys = keys.map { $0.toHex(includePrefix: true) }

            subscriptionId = try connection.subscribe(
                RPCMethod.storageSubscribe,
                params: [storageKeys],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
        } catch {
            notify(result: .failure(error))
        }
    }

    func unsubscribe() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        encondingOperations?.forEach { $0.cancel() }
        encondingOperations = nil

        guard let subscriptionId = subscriptionId else {
            return
        }

        connection.cancelForIdentifier(subscriptionId)
    }

    private func notify(result: Result<T, Error>) {
        callbackQueue.async { [weak self] in
            self?.callbackClosure(result)
        }
    }

    private func findRequests(
        for changes: [StorageUpdateData.StorageUpdateChangeData],
        keys: [Data]
    ) -> [BatchStorageSubscriptionRequest] {
        let receivedKeys = Set(changes.map(\.key))
        return zip(requests, keys).compactMap { receivedKeys.contains($0.1) ? $0.0 : nil }
    }

    func processUpdate(
        _ changes: [StorageUpdateData.StorageUpdateChangeData],
        keys: [Data],
        blockHash: Data?
    ) {
        let requests = findRequests(for: changes, keys: keys)
        saveIfNeeded(changes: changes, requests: requests)

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let decodingOperations: [BaseOperation<JSON>] = zip(changes, requests).map { change, request in
            if let data = change.value {
                let decodingOperation = StorageJSONDecodingOperation(path: request.innerRequest.storagePath, data: data)
                decodingOperation.configurationBlock = {
                    do {
                        decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                    } catch {
                        decodingOperation.result = .failure(error)
                    }
                }

                return decodingOperation
            } else {
                return BaseOperation.createWithResult(JSON.null)
            }
        }

        let mergeOperation = ClosureOperation<T> {
            let jsonList = try decodingOperations.map { try $0.extractNoCancellableResultData() }
            let blockHashJson = blockHash.map { JSON.stringValue($0.toHex()) } ?? JSON.null
            let context = try codingFactoryOperation.extractNoCancellableResultData().createRuntimeJsonContext()
            let values = zip(jsonList, requests).map {
                BatchStorageSubscriptionResultValue(mappingKey: $0.1.mappingKey, value: $0.0)
            }
            return try T(
                values: values,
                blockHashJson: blockHashJson,
                context: context.toRawContext()
            )
        }

        decodingOperations.forEach { decodingOperation in
            decodingOperation.addDependency(codingFactoryOperation)
            mergeOperation.addDependency(decodingOperation)
        }

        if let previousOperation = previousOperation {
            codingFactoryOperation.addDependency(previousOperation)
        }

        previousOperation = mergeOperation

        mergeOperation.completionBlock = { [weak self] in
            do {
                let value = try mergeOperation.extractNoCancellableResultData()
                self?.notify(result: .success(value))
            } catch {
                self?.notify(result: .failure(error))
            }
        }

        let operations = [codingFactoryOperation] + decodingOperations + [mergeOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func saveIfNeeded(
        changes: [StorageUpdateData.StorageUpdateChangeData],
        requests: [BatchStorageSubscriptionRequest]
    ) {
        guard let repository = repository else {
            return
        }

        let pairs = zip(changes, requests).filter { !$0.1.innerRequest.localKey.isEmpty }

        let operation = repository.saveOperation({
            pairs.compactMap { change, request in
                guard let data = change.value else {
                    return nil
                }

                return ChainStorageItem(identifier: request.innerRequest.localKey, data: data)
            }
        }, {
            pairs.compactMap { change, request in
                if change.value == nil {
                    return request.innerRequest.localKey
                } else {
                    return nil
                }
            }
        })

        operationQueue.addOperation(operation)
    }
}
