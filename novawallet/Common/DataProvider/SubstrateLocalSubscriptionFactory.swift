import Foundation
import Operation_iOS
import SubstrateSdk

class SubstrateLocalSubscriptionFactory {
    private var providers: [String: WeakWrapper] = [:]

    let chainRegistry: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol
    let stremableProviderFactory: SubstrateDataProviderFactoryProtocol

    private let mutex = NSLock()

    init(
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
        self.operationManager = operationManager
        self.logger = logger
        stremableProviderFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
    }

    func saveProvider(_ provider: AnyObject, for key: String) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        providers[key] = WeakWrapper(target: provider)
    }

    func getProvider(for key: String) -> AnyObject? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return providers[key]?.target
    }

    func clearIfNeeded() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        providers = providers.filter { $0.value.target != nil }
    }

    func getPlainProvider<T: Equatable & Decodable>(
        for chainId: ChainModel.Id,
        storagePath: StorageCodingPath,
        shouldUseFallback: Bool = false
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> {
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: storagePath,
            shouldUseFallback: shouldUseFallback
        )
    }

    func getAccountProvider<T: Equatable & Decodable>(
        for chainId: ChainModel.Id,
        accountId: AccountId,
        storagePath: StorageCodingPath
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> {
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            accountId: accountId,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: storagePath,
            shouldUseFallback: false
        )
    }

    func getDataProvider<T>(
        for localKey: String,
        chainId: ChainModel.Id,
        storageCodingPath: StorageCodingPath,
        shouldUseFallback: Bool
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> where T: Equatable & Decodable {
        try getDataProvider(
            for: localKey,
            chainId: chainId,
            possibleCodingPaths: [storageCodingPath],
            shouldUseFallback: shouldUseFallback
        )
    }

    func getDataProvider<T>(
        for localKey: String,
        chainId: ChainModel.Id,
        possibleCodingPaths: [StorageCodingPath],
        shouldUseFallback: Bool
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> where T: Equatable & Decodable {
        let fallback = StorageProviderSourceFallback<T>(
            usesRuntimeFallback: shouldUseFallback,
            missingEntryStrategy: .defaultValue(nil)
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            possibleCodingPaths: possibleCodingPaths,
            fallback: fallback
        )
    }

    func getDataProvider<T>(
        for localKey: String,
        chainId: ChainModel.Id,
        storageCodingPath: StorageCodingPath,
        fallback: StorageProviderSourceFallback<T>
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> where T: Equatable & Decodable {
        try getDataProvider(
            for: localKey,
            chainId: chainId,
            possibleCodingPaths: [storageCodingPath],
            fallback: fallback
        )
    }

    func getDataProvider<T>(
        for localKey: String,
        chainId: ChainModel.Id,
        possibleCodingPaths: [StorageCodingPath],
        fallback: StorageProviderSourceFallback<T>
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> where T: Equatable & Decodable {
        clearIfNeeded()

        if let dataProvider = getProvider(for: localKey) as? DataProvider<ChainStorageDecodedItem<T>> {
            return AnyDataProvider(dataProvider)
        }

        guard let runtimeCodingProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let repository = InMemoryDataProviderRepository<ChainStorageDecodedItem<T>>()

        let streamableProvider = stremableProviderFactory.createStorageProvider(for: localKey)

        let trigger = DataProviderProxyTrigger()
        let source: StorageProviderSource<T> = StorageProviderSource(
            itemIdentifier: localKey,
            possibleCodingPaths: possibleCodingPaths,
            runtimeService: runtimeCodingProvider,
            provider: streamableProvider,
            trigger: trigger,
            fallback: fallback,
            operationManager: operationManager
        )

        let dataProvider = DataProvider(
            source: AnyDataProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        saveProvider(dataProvider, for: localKey)

        return AnyDataProvider(dataProvider)
    }

    func getNoFallbackPathProvider<T: Decodable & Equatable>(
        for storagePath: StorageCodingPath,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> {
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(storagePath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: storagePath,
            shouldUseFallback: false
        )
    }

    func getNoFallbackAccountProvider<T: Decodable & Equatable>(
        for storagePath: StorageCodingPath,
        accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> {
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            accountId: accountId,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: storagePath,
            shouldUseFallback: false
        )
    }

    func getNoFallbackScalingElementProvider<T: Decodable & Equatable, E: ScaleEncodable>(
        for storagePath: StorageCodingPath,
        encodableElement: E,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> {
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            encodableElement: encodableElement,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: storagePath,
            shouldUseFallback: false
        )
    }
}
