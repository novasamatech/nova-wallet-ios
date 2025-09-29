import Foundation
import Operation_iOS
import Keystore_iOS
import Foundation_iOS

typealias AHMInfoPreSyncServiceProtocol = PreSyncServiceProtocol & AHMInfoServiceProtocol

protocol AHMInfoServiceProtocol: AnyProviderAutoCleaning {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<[AHMRemoteData]?>.StateChangeClosure
    )
    func remove(observer: AnyObject)
    func reset()
    func exclude(sourceChainId: ChainModel.Id)
}

final class AHMInfoService: BaseObservableStateStore<[AHMRemoteData]> {
    private let blockNumberOperationFactory: BlockNumberOperationFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let applicationHandler: ApplicationHandlerProtocol
    private let ahmInfoRepository: AHMInfoRepositoryProtocol
    private let assetBalanceRepository: AnyDataProviderRepository<AssetBalance>
    private let settingsManager: SettingsManagerProtocol

    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue

    private let callStore = CancellableCallStore()

    private var balances: [ChainAssetId: AssetBalance] = [:] {
        didSet {
            guard balances != oldValue else { return }
            updateState()
        }
    }

    init(
        blockNumberOperationFactory: BlockNumberOperationFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        ahmInfoRepository: AHMInfoRepositoryProtocol,
        assetBalanceRepository: AnyDataProviderRepository<AssetBalance>,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.blockNumberOperationFactory = blockNumberOperationFactory
        self.chainRegistry = chainRegistry
        self.applicationHandler = applicationHandler
        self.ahmInfoRepository = ahmInfoRepository
        self.assetBalanceRepository = assetBalanceRepository
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue

        super.init(logger: logger)
    }
}

// MARK: - Private

private extension AHMInfoService {
    func createSetupWrapper() -> CompoundOperationWrapper<Void> {
        let assetBalanceFetchOperation = assetBalanceRepository.fetchAllOperation(with: .init())

        let resultOperation = ClosureOperation { [weak self] in
            guard let self else { return }

            let allBalances = try assetBalanceFetchOperation.extractNoCancellableResultData()

            mutex.lock()

            balances = allBalances.reduce(into: balances) { $0[$1.chainAssetId] = $1 }

            mutex.unlock()
        }

        resultOperation.addDependency(assetBalanceFetchOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [assetBalanceFetchOperation]
        )
    }

    func createUpdatedConfigsWrapper() -> CompoundOperationWrapper<[AHMRemoteData]> {
        let relevantConfigsWrapper = createRelevantConfigsWrapper()

        let migrationTimestampsOperation = createMigrationTimestampsOperation(
            dependingOn: relevantConfigsWrapper
        )

        migrationTimestampsOperation.addDependency(relevantConfigsWrapper.targetOperation)

        let resultOperation: BaseOperation<[AHMRemoteData]> = ClosureOperation {
            let configs = try relevantConfigsWrapper.targetOperation.extractNoCancellableResultData()

            let timestamps = try migrationTimestampsOperation
                .extractNoCancellableResultData()
                .compactMap { $0 }
                .reduce(into: [:]) { $0[$1.0] = $1.1 }

            return configs.filter {
                guard let timestamp = timestamps[$0.sourceData.chainId] else { return false }

                return Date(timeIntervalSince1970: TimeInterval(timestamp)) <= Date()
            }
        }

        resultOperation.addDependency(migrationTimestampsOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: relevantConfigsWrapper.allOperations + [migrationTimestampsOperation]
        )
    }

    func createRelevantConfigsWrapper() -> CompoundOperationWrapper<[AHMRemoteData]> {
        let ahmInfoWrapper = ahmInfoRepository.fetchAllWrapper()

        let resultOperation = ClosureOperation<[AHMRemoteData]> { [weak self] in
            guard let self else { return [] }

            let shownChains = settingsManager.ahmInfoShownChains

            let ahmInfoConfigs = try ahmInfoWrapper.targetOperation.extractNoCancellableResultData()

            mutex.lock()
            let relevantConfigs = ahmInfoConfigs.filter {
                let chainAssetId = ChainAssetId(
                    chainId: $0.sourceData.chainId,
                    assetId: $0.sourceData.assetId
                )

                return !shownChains.chainIds.contains(chainAssetId.chainId)
                    && self.balances[chainAssetId] != nil
            }
            mutex.unlock()

            return relevantConfigs
        }

        resultOperation.addDependency(ahmInfoWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: ahmInfoWrapper.allOperations
        )
    }

    func createMigrationTimestampsOperation(
        dependingOn configsWrapper: CompoundOperationWrapper<[AHMRemoteData]>
    ) -> BaseOperation<[MigrationTimeStamp]> {
        OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self else { return [] }

            let configs = try configsWrapper
                .targetOperation
                .extractNoCancellableResultData()
                .reduce(into: [:]) { $0[$1.sourceData.chainId] = $1 }

            let runtimeProviders = configs.keys.reduce(into: [:]) { acc, chainId in
                acc[chainId] = self.chainRegistry.getRuntimeProvider(for: chainId)
            }

            return configs.compactMap { chainId, config in
                guard
                    let chain = self.chainRegistry.getChain(for: chainId),
                    let runtimeProvider = self.chainRegistry.getRuntimeProvider(for: chainId)
                else { return nil }

                return self.createMigrationTimestampWrapper(
                    for: chain,
                    runtimeProvider: runtimeProvider,
                    targetBlockNumber: config.blockNumber
                )
            }
        }.longrunOperation()
    }

    func createMigrationTimestampWrapper(
        for chain: ChainModel,
        runtimeProvider: RuntimeProviderProtocol,
        targetBlockNumber: BlockNumber
    ) -> CompoundOperationWrapper<MigrationTimeStamp> {
        let currentBlockWrapper = blockNumberOperationFactory.createWrapper(
            for: chain.chainId
        )
        let blocktimeWrapper = BlockTimeOperationFactory(chain: chain).createExpectedBlockTimeWrapper(
            from: runtimeProvider
        )

        let resultOperation: BaseOperation<MigrationTimeStamp> = ClosureOperation {
            let currentBlock = try currentBlockWrapper.targetOperation.extractNoCancellableResultData()
            let blocktime = try blocktimeWrapper.targetOperation.extractNoCancellableResultData()

            let timestamp = BlockTimestampEstimator.estimateTimestamp(
                for: targetBlockNumber,
                currentBlock: currentBlock,
                blockTimeInMillis: blocktime
            )

            return (chain.chainId, timestamp)
        }

        resultOperation.addDependency(currentBlockWrapper.targetOperation)
        resultOperation.addDependency(blocktimeWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: currentBlockWrapper.allOperations + blocktimeWrapper.allOperations
        )
    }

    func updateState() {
        let wrapper = createUpdatedConfigsWrapper()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(configs):
                guard stateObservable.state != configs else { return }

                stateObservable.state = configs
            case let .failure(error):
                logger.error("Failed to update AHM info state: \(error)")
            }
        }
    }
}

// MARK: - AHMInfoServiceProtocol

extension AHMInfoService: AHMInfoPreSyncServiceProtocol {
    func setup() -> CompoundOperationWrapper<Void> {
        mutex.lock()
        defer { mutex.unlock() }

        applicationHandler.delegate = self

        return createSetupWrapper()
    }

    func throttle() {
        mutex.lock()
        defer { mutex.unlock() }

        callStore.cancel()
    }

    func exclude(sourceChainId: ChainModel.Id) {
        var updatedChainIds = settingsManager.ahmInfoShownChains.chainIds
        updatedChainIds.insert(sourceChainId)

        settingsManager.ahmInfoShownChains = AHMInfoShownChains(chainIds: updatedChainIds)
    }
}

// MARK: - ApplicationHandlerDelegate

extension AHMInfoService: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        updateState()
    }
}

// MARK: - Private types

private extension AHMInfoService {
    typealias MigrationTimeStamp = (ChainModel.Id, UInt64)
}
