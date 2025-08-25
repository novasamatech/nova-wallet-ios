import Foundation
import SubstrateSdk
import Operation_iOS

typealias HydrationAccountBalanceMap = [HydraAccountAsset: HydraBalance]
typealias HydrationAssetMetadataMap = [HydraDx.AssetId: HydraAssetRegistry.Asset]

final class HydraBalanceSyncer: ObservableSyncService {
    typealias TState = HydrationAccountBalanceMap

    let accountAssets: Set<HydraAccountAsset>
    let runtimeProvider: RuntimeProviderProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue

    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let callStore = CancellableCallStore()

    private var evmBalanceSyncer: HydraEvmBalanceSyncer?
    private var substrateBalanceSyncer: HydraSubstrateBalanceSyncer?
    private var metadata: [HydraDx.AssetId: HydraAssetRegistry.Asset]?

    init(
        accountAssets: Set<HydraAccountAsset>,
        runtimeProvider: RuntimeProviderProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.accountAssets = accountAssets
        self.runtimeProvider = runtimeProvider
        self.connection = connection
        self.operationQueue = operationQueue
        self.workQueue = workQueue

        storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        super.init(logger: logger)
    }

    override func performSyncUp() {
        callStore.cancel()

        let metadataWrapper = createMetadataWrapper()

        executeCancellable(
            wrapper: metadataWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(metadata):
                self?.metadata = metadata
                self?.setupSyncServices(for: metadata)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    override func stopSyncUp() {
        callStore.cancel()

        clearSyncers()
    }

    func getBalancesState() -> HydrationAccountBalanceMap? {
        getState()
    }

    func getMetadataState() -> HydrationAssetMetadataMap? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return metadata
    }
}

private extension HydraBalanceSyncer {
    func clearSyncers() {
        substrateBalanceSyncer?.throttle()
        substrateBalanceSyncer = nil

        evmBalanceSyncer?.throttle()
        evmBalanceSyncer = nil
    }

    func setupSyncServices(for metadata: [HydraDx.AssetId: HydraAssetRegistry.Asset]) {
        clearSyncers()

        let evmAccountAssets = accountAssets.filter { accountAsset in
            metadata[accountAsset.assetId]?.assetType == .erc20
        }

        let ormlOrNativeAssets = accountAssets.subtracting(evmAccountAssets)

        if !evmAccountAssets.isEmpty {
            setupEvmSyncer(for: evmAccountAssets)
        }

        if !ormlOrNativeAssets.isEmpty {
            setupSubstrateSyncer(for: ormlOrNativeAssets)
        }
    }

    func setupEvmSyncer(for assets: Set<HydraAccountAsset>) {
        let syncer = HydraEvmBalanceSyncer(
            accountAssets: assets,
            runtimeProvider: runtimeProvider,
            connection: connection,
            operationQueue: operationQueue,
            workQueue: workQueue,
            logger: logger
        )

        evmBalanceSyncer = syncer

        syncer.setup()

        syncer.subscribeSyncState(
            self,
            queue: workQueue
        ) { [weak self] _, _ in
            guard let self else {
                return
            }

            mutex.lock()

            defer {
                mutex.unlock()
            }

            updateIsSyncing()
        }
    }

    func setupSubstrateSyncer(for assets: Set<HydraAccountAsset>) {
        let syncer = HydraSubstrateBalanceSyncer(
            accountAssets: assets,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            workQueue: workQueue,
            logger: logger
        )

        substrateBalanceSyncer = syncer

        syncer.setup()

        syncer.subscribeSyncState(
            self,
            queue: workQueue
        ) { [weak self] _, _ in
            guard let self else {
                return
            }

            mutex.lock()

            defer {
                mutex.unlock()
            }

            updateIsSyncing()
        }
    }

    func updateIsSyncing() {
        let evmIsSyncing = evmBalanceSyncer?.getIsSyncing() ?? false
        let substrateIsSyncing = substrateBalanceSyncer?.getIsSyncing() ?? false

        isSyncing = evmIsSyncing || substrateIsSyncing
    }

    func createMetadataWrapper() -> CompoundOperationWrapper<[HydraDx.AssetId: HydraAssetRegistry.Asset]> {
        let allAssets = accountAssets.map(\.assetId).distinct()

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<HydraAssetRegistry.Asset>]>
        wrapper = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: {
                allAssets.map { StringCodable(wrappedValue: $0) }
            },
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: HydraAssetRegistry.assetsPath
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<[HydraDx.AssetId: HydraAssetRegistry.Asset]> {
            let responses = try wrapper.targetOperation.extractNoCancellableResultData()

            return zip(allAssets, responses).reduce(
                into: [HydraDx.AssetId: HydraAssetRegistry.Asset]()
            ) { accum, pair in
                accum[pair.0] = pair.1.value
            }
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return wrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: mappingOperation)
    }
}

extension HydraBalanceSyncer: ObservableSubscriptionSyncServiceProtocol {
    func getState() -> TState? {
        let evmState = evmBalanceSyncer?.getState() ?? [:]
        let substrateState = (try? substrateBalanceSyncer?.getDecodedState()) ?? [:]

        return evmState.merging(substrateState) { _, balance2 in balance2 }
    }
}
