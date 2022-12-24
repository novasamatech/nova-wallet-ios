import UIKit
import RobinHood

final class TokensManageInteractor {
    weak var presenter: TokensManageInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let operationQueue: OperationQueue

    private weak var pendingOperation: BaseOperation<Void>?

    init(
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.repositoryFactory = repositoryFactory
        self.operationQueue = operationQueue
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
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
}

extension TokensManageInteractor: TokensManageInteractorInputProtocol {
    func setup() {
        subscribeChains()
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
}
