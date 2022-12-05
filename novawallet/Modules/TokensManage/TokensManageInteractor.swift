import UIKit
import RobinHood

final class TokensManageInteractor {
    weak var presenter: TokensManageInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue

    private weak var pendingOperation: BaseOperation<Void>?

    init(
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.repository = repository
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
    }
}
