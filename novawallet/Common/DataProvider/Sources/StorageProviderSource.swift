import Foundation
import RobinHood
import SubstrateSdk

final class StorageProviderSource<T: Decodable & Equatable>: DataProviderSourceProtocol {
    enum LastSeen: Equatable {
        case waiting
        case received(value: ChainStorageItem?)

        var data: Data? {
            switch self {
            case .waiting:
                return nil
            case let .received(item):
                return item?.data
            }
        }
    }

    typealias Model = ChainStorageDecodedItem<T>

    let itemIdentifier: String
    let codingPath: StorageCodingPath
    let runtimeService: RuntimeCodingServiceProtocol
    let provider: StreamableProvider<ChainStorageItem>
    let trigger: DataProviderTriggerProtocol
    let fallback: StorageProviderSourceFallback<T>

    private var lastSeenResult: LastSeen = .waiting
    private var lastSeenError: Error?

    private var lock = NSLock()

    init(
        itemIdentifier: String,
        codingPath: StorageCodingPath,
        runtimeService: RuntimeCodingServiceProtocol,
        provider: StreamableProvider<ChainStorageItem>,
        trigger: DataProviderTriggerProtocol,
        fallback: StorageProviderSourceFallback<T>
    ) {
        self.itemIdentifier = itemIdentifier
        self.codingPath = codingPath
        self.runtimeService = runtimeService
        self.provider = provider
        self.trigger = trigger
        self.fallback = fallback

        subscribe()
    }

    // MARK: Private

    private func replaceAndNotifyIfNeeded(_ newItem: ChainStorageItem?) {
        let newValue = LastSeen.received(value: newItem)
        if newValue != lastSeenResult || lastSeenError != nil {
            lock.lock()

            lastSeenError = nil
            lastSeenResult = newValue

            lock.unlock()

            trigger.delegate?.didTrigger()
        }
    }

    private func replaceAndNotifyError(_ error: Error) {
        lock.lock()

        lastSeenResult = .waiting
        lastSeenError = error

        lock.unlock()

        trigger.delegate?.didTrigger()
    }

    private func subscribe() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<ChainStorageItem>]) in
            let finalItem: ChainStorageItem? = changes.reduceToLastChange()
            self?.replaceAndNotifyIfNeeded(finalItem)
        }

        let failure = { [weak self] (error: Error) in
            self?.replaceAndNotifyError(error)
            return
        }

        provider.addObserver(
            self,
            deliverOn: DispatchQueue.global(qos: .default),
            executing: updateClosure,
            failing: failure,
            options: StreamableProviderObserverOptions.substrateSource()
        )
    }

    private func prepareFallbackBaseOperation(
        for missingEntryStrategy: MissingRuntimeEntryStrategy<T>
    ) -> CompoundOperationWrapper<T?> {
        if let error = lastSeenError {
            return CompoundOperationWrapper<T?>.createWithError(error)
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let decodingOperation = StorageFallbackDecodingOperation<T>(
            path: codingPath,
            data: lastSeenResult.data
        )
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        let mappingOperation: BaseOperation<T?> = ClosureOperation {
            do {
                return try decodingOperation.extractNoCancellableResultData()
            } catch StorageDecodingOperationError.invalidStoragePath {
                switch missingEntryStrategy {
                case .emitError:
                    throw StorageDecodingOperationError.invalidStoragePath
                case let .defaultValue(value):
                    return value
                }
            }
        }

        mappingOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation, decodingOperation]
        )
    }

    private func prepareOptionalBaseNillOperation(
        for missingEntryStrategy: MissingRuntimeEntryStrategy<T>,
        codingPath: StorageCodingPath
    ) -> CompoundOperationWrapper<T?> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let mapOperation = ClosureOperation<T?> {
            let runtime = try codingFactoryOperation.extractNoCancellableResultData().metadata

            if runtime.getStorageMetadata(in: codingPath.moduleName, storageName: codingPath.itemName) != nil {
                return nil
            } else {
                switch missingEntryStrategy {
                case .emitError:
                    throw StorageDecodingOperationError.invalidStoragePath
                case let .defaultValue(value):
                    return value
                }
            }
        }

        mapOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [codingFactoryOperation])
    }

    private func prepareOptionalBaseOperation(
        for missingEntryStrategy: MissingRuntimeEntryStrategy<T>
    ) -> CompoundOperationWrapper<T?> {
        if let error = lastSeenError {
            return CompoundOperationWrapper<T?>.createWithError(error)
        }

        guard let data = lastSeenResult.data else {
            return prepareOptionalBaseNillOperation(for: missingEntryStrategy, codingPath: codingPath)
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let decodingOperation = StorageDecodingOperation<T>(path: codingPath, data: data)
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        let mappingOperation: BaseOperation<T?> = ClosureOperation {
            try decodingOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation, decodingOperation]
        )
    }
}

extension StorageProviderSource {
    func fetchOperation(by modelId: String) -> CompoundOperationWrapper<Model?> {
        lock.lock()

        defer {
            lock.unlock()
        }

        guard modelId == itemIdentifier else {
            let value = ChainStorageDecodedItem<T>(identifier: modelId, item: nil)
            return CompoundOperationWrapper<Model?>.createWithResult(value)
        }

        let baseOperationWrapper = fallback.usesRuntimeFallback ?
            prepareFallbackBaseOperation(for: fallback.missingEntryStrategy) :
            prepareOptionalBaseOperation(for: fallback.missingEntryStrategy)
        let mappingOperation: BaseOperation<Model?> = ClosureOperation {
            if let item = try baseOperationWrapper.targetOperation.extractNoCancellableResultData() {
                return ChainStorageDecodedItem(identifier: modelId, item: item)
            } else {
                return ChainStorageDecodedItem(identifier: modelId, item: nil)
            }
        }

        let dependencies = baseOperationWrapper.allOperations
        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: dependencies
        )
    }

    func fetchOperation(page _: UInt) -> CompoundOperationWrapper<[Model]> {
        lock.lock()

        defer {
            lock.unlock()
        }

        let currentId = itemIdentifier

        let baseOperationWrapper = fallback.usesRuntimeFallback ?
            prepareFallbackBaseOperation(for: fallback.missingEntryStrategy) :
            prepareOptionalBaseOperation(for: fallback.missingEntryStrategy)
        let mappingOperation: BaseOperation<[Model]> = ClosureOperation {
            if let item = try baseOperationWrapper.targetOperation.extractNoCancellableResultData() {
                return [ChainStorageDecodedItem(identifier: currentId, item: item)]
            } else {
                return [ChainStorageDecodedItem(identifier: currentId, item: nil)]
            }
        }

        let dependencies = baseOperationWrapper.allOperations
        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: dependencies
        )
    }
}
