import Foundation

extension ChainsStoreProtocol {
    func getAllStakebleAssets() -> Set<ChainAsset> {
        let chainAssets = availableChainIds().flatMap { chainId in
            guard let chain = getChain(for: chainId) else {
                return [ChainAsset]()
            }

            return chain.assets.compactMap { asset in
                asset.hasStaking ? ChainAsset(chain: chain, asset: asset) : nil
            }
        }

        return Set(chainAssets)
    }
}
