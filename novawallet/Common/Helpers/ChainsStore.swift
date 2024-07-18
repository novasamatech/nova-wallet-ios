import Foundation

typealias ChainsStoreFilter = (ChainModel) -> Bool

protocol ChainsStoreDelegate: AnyObject {
    func didUpdateChainsStore(_ chainsStore: ChainsStoreProtocol)
}

protocol ChainsStoreProtocol: AnyObject {
    var delegate: ChainsStoreDelegate? { get set }

    func setup(with filter: ChainsStoreFilter?)

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

    func setup(with filter: ChainsStoreFilter? = nil) {
        setup(with: filter)
    }
}

final class ChainsStore {
    let chainRegistry: ChainRegistryProtocol

    weak var delegate: ChainsStoreDelegate?

    var filter: ChainsStoreFilter?

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

extension ChainsStore: ChainsStoreProtocol {
    func setup(with filter: ChainsStoreFilter?) {
        self.filter = filter

        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }

            strongSelf.delegate?.didUpdateChainsStore(strongSelf)
        }
    }

    func availableChainIds() -> Set<ChainModel.Id> {
        guard let availableChainIds = chainRegistry.availableChainIds else {
            return Set()
        }

        guard let filter else {
            return availableChainIds
        }

        let filteredIds = availableChainIds
            .compactMap { chainRegistry.getChain(for: $0) }
            .filter { filter($0) }
            .map(\.chainId)

        return Set(filteredIds)
    }

    func getChain(for chainId: ChainModel.Id) -> ChainModel? {
        let chain = chainRegistry.getChain(for: chainId)

        guard let filter, let chain else { return chain }

        return filter(chain) ? chain : nil
    }
}
