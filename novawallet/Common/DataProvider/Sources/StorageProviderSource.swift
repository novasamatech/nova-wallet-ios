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
    let possibleCodingPaths: [StorageCodingPath]
    let runtimeService: RuntimeCodingServiceProtocol
    let provider: StreamableProvider<ChainStorageItem>
    let trigger: DataProviderTriggerProtocol
    let fallback: StorageProviderSourceFallback<T>
    let operationManager: OperationManagerProtocol

    private var lastSeenResult: LastSeen = .waiting
    private var lastSeenError: Error?

    private var lock = NSLock()

    init(
        itemIdentifier: String,
        possibleCodingPaths: [StorageCodingPath],
        runtimeService: RuntimeCodingServiceProtocol,
        provider: StreamableProvider<ChainStorageItem>,
        trigger: DataProviderTriggerProtocol,
        fallback: StorageProviderSourceFallback<T>,
        operationManager: OperationManagerProtocol
    ) {
        self.itemIdentifier = itemIdentifier
        self.possibleCodingPaths = possibleCodingPaths
        self.runtimeService = runtimeService
        self.provider = provider
        self.trigger = trigger
        self.fallback = fallback
        self.operationManager = operationManager

        subscribe()
    }

    convenience init(
        itemIdentifier: String,
        codingPath: StorageCodingPath,
        runtimeService: RuntimeCodingServiceProtocol,
        provider: StreamableProvider<ChainStorageItem>,
        trigger: DataProviderTriggerProtocol,
        fallback: StorageProviderSourceFallback<T>,
        operationManager: OperationManagerProtocol
    ) {
        self.init(
            itemIdentifier: itemIdentifier,
            possibleCodingPaths: [codingPath],
            runtimeService: runtimeService,
            provider: provider,
            trigger: trigger,
            fallback: fallback,
            operationManager: operationManager
        )
    }

    // MARK: Private

    private func replaceAndNotifyIfNeeded(_ newItem: ChainStorageItem?) {
        lock.lock()

        let newValue = LastSeen.received(value: newItem)
        let shouldUpdate = newValue != lastSeenResult || lastSeenError != nil
        if shouldUpdate {
            lastSeenError = nil
            lastSeenResult = newValue
        }

        lock.unlock()

        if shouldUpdate {
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
        for missingEntryStrategy: MissingRuntimeEntryStrategy<T>,
        storagePath: StorageCodingPath?,
        lastSeenResult: LastSeen,
        lastSeenError: Error?
    ) -> CompoundOperationWrapper<T?> {
        if let error = lastSeenError {
            return CompoundOperationWrapper<T?>.createWithError(error)
        }

        guard let storagePath = storagePath else {
            switch missingEntryStrategy {
            case .emitError:
                return CompoundOperationWrapper.createWithError(StorageDecodingOperationError.invalidStoragePath)
            case let .defaultValue(value):
                return CompoundOperationWrapper.createWithResult(value)
            }
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let decodingOperation = StorageFallbackDecodingOperation<T>(
            path: storagePath,
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

    private func prepareOptionalBaseNilOperation(
        for missingEntryStrategy: MissingRuntimeEntryStrategy<T>,
        storagePath: StorageCodingPath?
    ) -> CompoundOperationWrapper<T?> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let mapOperation = ClosureOperation<T?> {
            let runtime = try codingFactoryOperation.extractNoCancellableResultData().metadata

            if
                let storagePath = storagePath,
                runtime.getStorageMetadata(for: storagePath) != nil {
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
        for missingEntryStrategy: MissingRuntimeEntryStrategy<T>,
        storagePath: StorageCodingPath?,
        lastSeenResult: LastSeen,
        lastSeenError: Error?
    ) -> CompoundOperationWrapper<T?> {
        if let error = lastSeenError {
            return CompoundOperationWrapper<T?>.createWithError(error)
        }

        guard let storagePath = storagePath, let data = lastSeenResult.data else {
            return prepareOptionalBaseNilOperation(for: missingEntryStrategy, storagePath: storagePath)
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

        let mappingOperation: BaseOperation<T?> = ClosureOperation {
            try decodingOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation, decodingOperation]
        )
    }

    private func resolveCodingPathAndPrepareDecodingOperation(
        for codingPaths: [StorageCodingPath],
        fallback: StorageProviderSourceFallback<T>,
        lastSeenResult: LastSeen,
        lastSeenError: Error?
    ) -> CompoundOperationWrapper<T?> {
        let decodingWrapperClosure: (StorageCodingPath?) -> CompoundOperationWrapper<T?> = { storagePath in
            if fallback.usesRuntimeFallback {
                return self.prepareFallbackBaseOperation(
                    for: fallback.missingEntryStrategy,
                    storagePath: storagePath,
                    lastSeenResult: lastSeenResult,
                    lastSeenError: lastSeenError
                )
            } else {
                return self.prepareOptionalBaseOperation(
                    for: fallback.missingEntryStrategy,
                    storagePath: storagePath,
                    lastSeenResult: lastSeenResult,
                    lastSeenError: lastSeenError
                )
            }
        }

        guard codingPaths.count > 1 else {
            return decodingWrapperClosure(codingPaths.first)
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let resolutionOperation = ClosureOperation<StorageCodingPath?> {
            let metadata = try codingFactoryOperation.extractNoCancellableResultData().metadata
            return codingPaths.first { metadata.getStorageMetadata(for: $0) != nil }
        }

        resolutionOperation.addDependency(codingFactoryOperation)

        let decodingWrapper: CompoundOperationWrapper<T?> = OperationCombiningService.compoundOptionalWrapper(
            operationManager: operationManager
        ) {
            let storagePath = try resolutionOperation.extractNoCancellableResultData()
            return decodingWrapperClosure(storagePath)
        }

        decodingWrapper.addDependency(operations: [resolutionOperation])

        let dependencies = [codingFactoryOperation, resolutionOperation] + decodingWrapper.dependencies

        return CompoundOperationWrapper(
            targetOperation: decodingWrapper.targetOperation,
            dependencies: dependencies
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

        let baseOperationWrapper = resolveCodingPathAndPrepareDecodingOperation(
            for: possibleCodingPaths,
            fallback: fallback,
            lastSeenResult: lastSeenResult,
            lastSeenError: lastSeenError
        )

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

        let baseOperationWrapper = resolveCodingPathAndPrepareDecodingOperation(
            for: possibleCodingPaths,
            fallback: fallback,
            lastSeenResult: lastSeenResult,
            lastSeenError: lastSeenError
        )

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
