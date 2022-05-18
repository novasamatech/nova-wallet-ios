import Foundation
import SubstrateSdk
import RobinHood

final class CallbackStorageSubscription<T: Decodable> {
    let request: SubscriptionRequestProtocol
    let storagePath: StorageCodingPath
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue
    let repository: AnyDataProviderRepository<ChainStorageItem>?

    let callbackQueue: DispatchQueue
    let callbackClosure: (Result<T?, Error>) -> Void

    private var subscriptionId: UInt16?

    private weak var previousOperation: Operation?
    private var encondingOperations: [Operation]?

    private var mutex = NSLock()

    init(
        request: SubscriptionRequestProtocol,
        storagePath: StorageCodingPath,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        repository: AnyDataProviderRepository<ChainStorageItem>?,
        operationQueue: OperationQueue,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping (Result<T?, Error>) -> Void
    ) {
        self.request = request
        self.storagePath = storagePath
        self.connection = connection
        self.runtimeService = runtimeService
        self.repository = repository
        self.operationQueue = operationQueue
        self.callbackQueue = callbackQueue
        self.callbackClosure = callbackClosure

        encodeKeyAndSubscribe()
    }

    deinit {
        unsubscribe()
    }

    private func encodeKeyAndSubscribe() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let keyEncondingWrapper = request.createKeyEncodingWrapper(
            using: StorageKeyFactory(),
            codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() }
        )

        keyEncondingWrapper.addDependency(operations: [codingFactoryOperation])

        keyEncondingWrapper.targetOperation.completionBlock = { [weak self] in
            do {
                let key = try keyEncondingWrapper.targetOperation.extractNoCancellableResultData()
                self?.subscribe(with: key)
            } catch {
                self?.notify(result: .failure(error))
            }
        }

        let encondingOperations = [codingFactoryOperation] + keyEncondingWrapper.allOperations
        self.encondingOperations = encondingOperations

        operationQueue.addOperations(
            encondingOperations,
            waitUntilFinished: false
        )
    }

    private func subscribe(with key: Data) {
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
                if let change = updateData.changes.first {
                    self?.processUpdate(change.value, blockHash: updateData.blockHash)
                }
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, _ in
                self?.notify(result: .failure(error))
            }

            let storageKey = key.toHex(includePrefix: true)

            subscriptionId = try connection.subscribe(
                RPCMethod.storageSubscribe,
                params: [[storageKey]],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
        } catch {
            notify(result: .failure(error))
        }
    }

    private func unsubscribe() {
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

    private func notify(result: Result<T?, Error>) {
        callbackQueue.async { [weak self] in
            self?.callbackClosure(result)
        }
    }

    func processUpdate(_ data: Data?, blockHash _: Data?) {
        saveIfNeeded(data: data, localKey: request.localKey)

        guard let data = data else {
            notify(result: .success(nil))
            return
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<T>(path: storagePath, data: data)
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        if let previousOperation = previousOperation {
            codingFactoryOperation.addDependency(previousOperation)
        }

        previousOperation = decodingOperation

        decodingOperation.completionBlock = { [weak self] in
            do {
                let value = try decodingOperation.extractNoCancellableResultData()
                self?.notify(result: .success(value))
            } catch {
                self?.notify(result: .failure(error))
            }
        }

        operationQueue.addOperations([codingFactoryOperation, decodingOperation], waitUntilFinished: false)
    }

    private func saveIfNeeded(data: Data?, localKey: String) {
        guard let repository = repository else {
            return
        }

        let operation = repository.saveOperation({
            if let data = data {
                let item = ChainStorageItem(identifier: localKey, data: data)
                return [item]
            } else {
                return []
            }
        }, {
            if data == nil {
                return [localKey]
            } else {
                return []
            }
        })

        operationQueue.addOperation(operation)
    }
}
