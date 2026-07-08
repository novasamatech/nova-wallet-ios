import UIKit
import Operation_iOS
import Keystore_iOS

final class TokensManageInteractor {
    weak var presenter: TokensManageInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let defaultTokensService: DefaultTokensServiceProtocol

    private var settingsManager: SettingsManagerProtocol

    private weak var pendingOperation: BaseOperation<Void>?

    init(
        chainRegistry: ChainRegistryProtocol,
        eventCenter: EventCenterProtocol,
        settingsManager: SettingsManagerProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        operationQueue: OperationQueue,
        defaultTokensService: DefaultTokensServiceProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.eventCenter = eventCenter
        self.settingsManager = settingsManager
        self.repository = repository
        self.repositoryFactory = repositoryFactory
        self.operationQueue = operationQueue
        self.defaultTokensService = defaultTokensService
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main,
            filterStrategy: .enabledChains
        ) { [weak self] changes in
            self?.presenter?.didReceiveChainModel(changes: changes)
        }
    }

    private func createBalanceClearOperation(for chainAssetIds: Set<ChainAssetId>) -> BaseOperation<Void> {
        let repository = repositoryFactory.createAssetBalanceRepository(for: chainAssetIds)
        return repository.deleteAllOperation()
    }

    private func createLocksClearOperation(for chainAssetIds: Set<ChainAssetId>) -> BaseOperation<Void> {
        let repository = repositoryFactory.createAssetLocksRepository(chainAssetIds: chainAssetIds)
        return repository.deleteAllOperation()
    }

    private func createCrowdloanContributionClearOperation(
        for chainAssetIds: Set<ChainAssetId>
    ) -> BaseOperation<Void> {
        let chainIds = Set(chainAssetIds.filter { $0.assetId == 0 }.map(\.chainId))
        let repository = repositoryFactory.createCrowdloanContributionRepository(chainIds: chainIds)
        return repository.deleteAllOperation()
    }

    private func createTokenClearWrapper(for chainAssetIds: Set<ChainAssetId>) -> CompoundOperationWrapper<Void> {
        let clearBalanceOperation = createBalanceClearOperation(for: chainAssetIds)
        let clearLocksOperation = createLocksClearOperation(for: chainAssetIds)
        let clearCrowdloanContributionOperation = createCrowdloanContributionClearOperation(for: chainAssetIds)

        return CompoundOperationWrapper(
            targetOperation: clearBalanceOperation,
            dependencies: [clearLocksOperation, clearCrowdloanContributionOperation]
        )
    }

    private func provideHidesZeroBalances() {
        let hidesZeroBalances = settingsManager.hidesZeroBalances

        presenter?.didReceive(hideZeroBalances: hidesZeroBalances)
    }

    private func provideDustFilterSettings() {
        let enabled = settingsManager.dustFilterEnabled
        let threshold = settingsManager.dustFilterThreshold

        presenter?.didReceive(dustFilterEnabled: enabled, threshold: threshold)
    }
}

extension TokensManageInteractor: TokensManageInteractorInputProtocol {
    func setup() {
        subscribeChains()
        provideHidesZeroBalances()
        provideDustFilterSettings()
    }

    func save(chainAssetIds: Set<ChainAssetId>, enabled: Bool, allChains: [ChainModel]) {
        let chains = Set(chainAssetIds.map(\.chainId))

        let saveOperation = repository.saveOperation({
            allChains.compactMap { chain in
                guard chains.contains(chain.chainId) else {
                    return nil
                }

                let newAssets = chain.assets.map { asset in
                    if chainAssetIds.contains(ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)) {
                        return asset.byChanging(enabled: enabled)
                    } else {
                        return asset
                    }
                }

                return chain.byChanging(assets: Set(newAssets))
            }
        }, {
            []
        })

        if let pendingOperation = pendingOperation {
            saveOperation.addDependency(pendingOperation)

            saveOperation.configurationBlock = {
                do {
                    try pendingOperation.extractNoCancellableResultData()
                } catch {
                    saveOperation.cancel()
                }
            }
        }

        pendingOperation = saveOperation

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                if case .failure = saveOperation.result {
                    self?.presenter?.didFailChainSave()
                }
            }
        }

        operationQueue.addOperation(saveOperation)

        if !enabled {
            let clearTokenWrapper = createTokenClearWrapper(for: chainAssetIds)
            clearTokenWrapper.addDependency(operations: [saveOperation])
            operationQueue.addOperations(clearTokenWrapper.allOperations, waitUntilFinished: false)
        }
    }

    func save(hideZeroBalances: Bool) {
        let shouldNotify = hideZeroBalances != settingsManager.hidesZeroBalances

        settingsManager.hidesZeroBalances = hideZeroBalances

        provideHidesZeroBalances()

        if shouldNotify {
            eventCenter.notify(with: HideZeroBalancesChanged())
        }
    }

    func save(dustFilterEnabled: Bool) {
        let shouldNotify = dustFilterEnabled != settingsManager.dustFilterEnabled

        settingsManager.dustFilterEnabled = dustFilterEnabled

        provideDustFilterSettings()

        if shouldNotify {
            eventCenter.notify(with: DustFilterChanged())
        }
    }

    func save(dustFilterThreshold: Decimal) {
        let shouldNotify = dustFilterThreshold != settingsManager.dustFilterThreshold

        settingsManager.dustFilterThreshold = dustFilterThreshold

        provideDustFilterSettings()

        if shouldNotify {
            eventCenter.notify(with: DustFilterChanged())
        }
    }

    func getDefaultTokenIds() -> Set<ChainAssetId>? {
        defaultTokensService.defaultTokenIds
    }

    func getUserAddedTokens() -> Set<ChainAssetId> {
        settingsManager.userAddedTokens
    }

    func addUserAddedToken(_ chainAssetId: ChainAssetId) {
        settingsManager.addUserAddedToken(chainAssetId)
        eventCenter.notify(with: UserAddedTokensChanged())
    }

    func removeUserAddedToken(_ chainAssetId: ChainAssetId) {
        settingsManager.removeUserAddedToken(chainAssetId)
        eventCenter.notify(with: UserAddedTokensChanged())
    }

    func isDefaultFilterActive() -> Bool {
        guard let defaultTokenIds = defaultTokensService.defaultTokenIds, !defaultTokenIds.isEmpty else {
            return false
        }

        if settingsManager.hasUsedLoadMoreTokens {
            return false
        }

        return true
    }

    func fetchDefaultFilterState(completion: @escaping (Bool, Set<ChainAssetId>, Set<ChainAssetId>) -> Void) {
        defaultTokensService.fetch { [weak self] defaultIds in
            guard let self else { return }

            let defaults = defaultIds ?? []
            let userAdded = self.settingsManager.userAddedTokens

            guard !defaults.isEmpty, !self.settingsManager.hasUsedLoadMoreTokens else {
                completion(false, defaults, userAdded)
                return
            }

            // The filter is active for new wallets — we always assume active here
            // since the asset list presenter does the balance check
            completion(true, defaults, userAdded)
        }
    }
}
