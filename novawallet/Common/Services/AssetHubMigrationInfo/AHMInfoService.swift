import Foundation
import Operation_iOS
import Keystore_iOS
import Foundation_iOS

typealias AHMInfoPreSyncServiceProtocol = PreSyncServiceProtocol & AHMInfoServiceProtocol

protocol AHMInfoServiceProtocol {
    func fetchPassedMigrationsInfo() -> CompoundOperationWrapper<[AHMRemoteData]>
    func fetchPassedMigrationsInfo(by chainId: ChainModel.Id) -> CompoundOperationWrapper<AHMRemoteData?>
    func createSnapshot() -> AHMInfoService.Snapshot
}

final class AHMInfoService {
    private let blockNumberOperationFactory: BlockNumberOperationFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let applicationHandler: ApplicationHandlerProtocol
    private let ahmInfoRepository: AHMInfoRepositoryProtocol
    private let assetBalanceRepository: AnyDataProviderRepository<AssetBalance>
    private let settingsManager: SettingsManagerProtocol
    private let filterSetKeypath: FilterSetKeyPath

    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol

    private let mutex = NSLock()

    private var balances: [ChainAssetId: AssetBalance]

    init(
        blockNumberOperationFactory: BlockNumberOperationFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        ahmInfoRepository: AHMInfoRepositoryProtocol,
        assetBalanceRepository: AnyDataProviderRepository<AssetBalance>,
        settingsManager: SettingsManagerProtocol,
        filterSetKeypath: FilterSetKeyPath,
        initialBalances: [ChainAssetId: AssetBalance] = [:],
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.blockNumberOperationFactory = blockNumberOperationFactory
        self.chainRegistry = chainRegistry
        self.applicationHandler = applicationHandler
        self.ahmInfoRepository = ahmInfoRepository
        self.assetBalanceRepository = assetBalanceRepository
        self.settingsManager = settingsManager
        self.filterSetKeypath = filterSetKeypath
        balances = initialBalances
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: - Private

private extension AHMInfoService {
    func setBalances(_ balances: [AssetBalance]) {
        mutex.lock()
        defer { mutex.unlock() }

        self.balances = balances.reduce(into: self.balances) { $0[$1.chainAssetId] = $1 }
    }

    func fetchBalance(for chainAssetId: ChainAssetId) -> AssetBalance? {
        mutex.lock()
        defer { mutex.unlock() }

        return balances[chainAssetId]
    }

    func filteredConfigs(from configs: [AHMRemoteData]) -> [AHMRemoteData] {
        let excludedSet = settingsManager[keyPath: filterSetKeypath]

        let relevantConfigs = configs.filter {
            let chainAssetId = ChainAssetId(
                chainId: $0.sourceData.chainId,
                assetId: $0.sourceData.assetId
            )
            let balance = self.fetchBalance(for: chainAssetId)

            return !excludedSet.chainIds.contains(chainAssetId.chainId) && balance != nil
        }

        return relevantConfigs
    }

    func createSetupWrapper() -> CompoundOperationWrapper<Void> {
        let assetBalanceFetchOperation = assetBalanceRepository.fetchAllOperation(with: .init())

        let resultOperation = ClosureOperation { [weak self] in
            guard let self else { return }

            let allBalances = try assetBalanceFetchOperation.extractNoCancellableResultData()

            setBalances(allBalances)
        }

        resultOperation.addDependency(assetBalanceFetchOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [assetBalanceFetchOperation]
        )
    }

    func createUpdatedConfigsWrapper(for chainId: ChainModel.Id? = nil) -> CompoundOperationWrapper<[AHMRemoteData]> {
        let relevantConfigsWrapper = if let chainId {
            createRelevantConfigsWrapper(for: chainId)
        } else {
            createRelevantConfigsWrapper()
        }

        let chainCurrentBlockNumbersOperation = createChainBlockNumbersOperation(
            dependingOn: relevantConfigsWrapper
        )

        chainCurrentBlockNumbersOperation.addDependency(relevantConfigsWrapper.targetOperation)

        let resultOperation: BaseOperation<[AHMRemoteData]> = ClosureOperation {
            let configs = try relevantConfigsWrapper.targetOperation.extractNoCancellableResultData()

            let chainBlockNumbers = try chainCurrentBlockNumbersOperation
                .extractNoCancellableResultData()
                .compactMap { $0 }
                .reduce(into: [:]) { $0[$1.0] = $1.1 }

            return configs.filter { config in
                guard let currentBlockNumber = chainBlockNumbers[config.sourceData.chainId] else { return false }

                return config.blockNumber <= currentBlockNumber
            }
        }

        resultOperation.addDependency(chainCurrentBlockNumbersOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: relevantConfigsWrapper.allOperations + [chainCurrentBlockNumbersOperation]
        )
    }

    func createRelevantConfigsWrapper() -> CompoundOperationWrapper<[AHMRemoteData]> {
        let ahmInfoWrapper = ahmInfoRepository.fetchAllWrapper()

        let resultOperation = ClosureOperation<[AHMRemoteData]> { [weak self] in
            guard let self else { return [] }

            let ahmInfoConfigs = try ahmInfoWrapper.targetOperation.extractNoCancellableResultData()

            return filteredConfigs(from: ahmInfoConfigs)
        }

        resultOperation.addDependency(ahmInfoWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: ahmInfoWrapper.allOperations
        )
    }

    func createRelevantConfigsWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<[AHMRemoteData]> {
        let ahmInfoWrapper = ahmInfoRepository.fetch(by: chainId)

        let resultOperation = ClosureOperation<[AHMRemoteData]> { [weak self] in
            guard
                let self,
                let ahmInfoConfig = try ahmInfoWrapper.targetOperation.extractNoCancellableResultData()
            else { return [] }

            return filteredConfigs(from: [ahmInfoConfig])
        }

        resultOperation.addDependency(ahmInfoWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: ahmInfoWrapper.allOperations
        )
    }

    func createChainBlockNumbersOperation(
        dependingOn configsWrapper: CompoundOperationWrapper<[AHMRemoteData]>
    ) -> BaseOperation<[ChainCurrentBlockNumber]> {
        OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self else { return [] }

            let configs = try configsWrapper
                .targetOperation
                .extractNoCancellableResultData()
                .reduce(into: [:]) { $0[$1.sourceData.chainId] = $1 }

            return configs.compactMap { chainId, _ in
                guard
                    let chain = self.chainRegistry.getChain(for: chainId)
                else { return nil }

                return self.createCurrentBlockNumberWrapper(for: chain)
            }
        }.longrunOperation()
    }

    func createCurrentBlockNumberWrapper(
        for chain: ChainModel
    ) -> CompoundOperationWrapper<ChainCurrentBlockNumber> {
        let currentBlockWrapper = blockNumberOperationFactory.createWrapper(
            for: chain.chainId
        )

        let resultOperation: BaseOperation<ChainCurrentBlockNumber> = ClosureOperation {
            (
                chain.chainId,
                try currentBlockWrapper.targetOperation.extractNoCancellableResultData()
            )
        }

        resultOperation.addDependency(currentBlockWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: currentBlockWrapper.allOperations
        )
    }
}

// MARK: - AHMInfoServiceProtocol

extension AHMInfoService: AHMInfoPreSyncServiceProtocol {
    func setup() -> CompoundOperationWrapper<Void> {
        mutex.lock()
        defer { mutex.unlock() }

        return createSetupWrapper()
    }

    func throttle() {}

    func fetchPassedMigrationsInfo() -> CompoundOperationWrapper<[AHMRemoteData]> {
        createUpdatedConfigsWrapper()
    }

    func fetchPassedMigrationsInfo(by chainId: ChainModel.Id) -> CompoundOperationWrapper<AHMRemoteData?> {
        let wrapper = createUpdatedConfigsWrapper(for: chainId)

        let mapOperation = ClosureOperation<AHMRemoteData?> {
            let configs = try wrapper.targetOperation.extractNoCancellableResultData()

            return configs.first
        }

        mapOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: wrapper.allOperations
        )
    }

    func createSnapshot() -> Snapshot {
        Snapshot(
            initialBalances: balances,
            ahmInfoRepository: ahmInfoRepository
        )
    }
}

// MARK: - Memento

extension AHMInfoService {
    struct Snapshot {
        private let initialBalances: [ChainAssetId: AssetBalance]
        private let ahmInfoRepository: AHMInfoRepositoryProtocol

        init(
            initialBalances: [ChainAssetId: AssetBalance],
            ahmInfoRepository: AHMInfoRepositoryProtocol
        ) {
            self.initialBalances = initialBalances
            self.ahmInfoRepository = ahmInfoRepository
        }

        func restoreService(with filterSetKeypath: FilterSetKeyPath) -> AHMInfoPreSyncServiceProtocol {
            createService(with: filterSetKeypath)
        }

        private func createService(with filterSetKeypath: FilterSetKeyPath) -> AHMInfoService {
            let chainRegistry = ChainRegistryFacade.sharedRegistry
            let operationQueue = OperationManagerFacade.sharedDefaultQueue
            let substrateStorage = SubstrateDataStorageFacade.shared
            let repositoryFactory = SubstrateRepositoryFactory(storageFacade: substrateStorage)
            let settingsManager = SettingsManager.shared

            return AHMInfoService(
                blockNumberOperationFactory: BlockNumberOperationFactory(
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue
                ),
                chainRegistry: chainRegistry,
                applicationHandler: ApplicationHandler(),
                ahmInfoRepository: ahmInfoRepository,
                assetBalanceRepository: repositoryFactory.createAssetBalanceRepository(),
                settingsManager: settingsManager,
                filterSetKeypath: filterSetKeypath,
                initialBalances: initialBalances,
                operationQueue: operationQueue,
                logger: Logger.shared
            )
        }
    }
}

// MARK: - Internal types

extension AHMInfoService {
    typealias FilterSetKeyPath = KeyPath<
        SettingsManagerProtocol,
        AHMInfoExcludedChains
    >
}

// MARK: - Private types

private extension AHMInfoService {
    typealias ChainCurrentBlockNumber = (ChainModel.Id, BlockNumber)
}
