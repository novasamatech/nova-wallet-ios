import Foundation

protocol ChainsStoreDelegate: AnyObject {
    func didUpdateChainsStore(_ chainsStore: ChainsStoreProtocol)
}

protocol ChainsStoreProtocol: AnyObject {
    var delegate: ChainsStoreDelegate? { get set }

    func setup()

    func availableChainIds() -> Set<ChainModel.Id>
    func getChain(for chainId: ChainModel.Id) -> ChainModel?
}

extension ChainsStoreProtocol {
    func getChainAsset(for chainAssetId: ChainAssetId) -> ChainAsset? {
        guard
            let chain = getChain(for: chainAssetId.chainId),
            let asset = chain.asset(for: chainAssetId.assetId) else {
            return nil
        }

        return ChainAsset(chain: chain, asset: asset)
    }
}

final class ChainsStore {
    let chainRegistry: ChainRegistryProtocol

    weak var delegate: ChainsStoreDelegate?

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

extension ChainsStore: ChainsStoreProtocol {
    func setup() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }

            strongSelf.delegate?.didUpdateChainsStore(strongSelf)
        }
    }

    func availableChainIds() -> Set<ChainModel.Id> {
        chainRegistry.availableChainIds ?? Set()
    }

    func getChain(for chainId: ChainModel.Id) -> ChainModel? {
        chainRegistry.getChain(for: chainId)
    }
}
