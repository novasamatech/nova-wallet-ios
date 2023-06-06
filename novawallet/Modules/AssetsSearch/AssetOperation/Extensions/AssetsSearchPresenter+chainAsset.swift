extension AssetsSearchPresenter {
    func chainAsset(for chainAssetId: ChainAssetId) -> ChainAsset? {
        let chainId = chainAssetId.chainId
        let assetId = chainAssetId.assetId

        guard let chain = allChains[chainId],
              let asset = chain.assets.first(where: { $0.assetId == assetId }) else {
            return nil
        }

        return .init(chain: chain, asset: asset)
    }
}
