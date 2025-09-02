import Foundation
import SubstrateSdk

struct XcmDynamicTransfers: Decodable {
    typealias AssetLocation = JSON
    typealias AssetLocationId = String
    typealias AssetIdKey = String

    let assetsLocation: [AssetLocationId: AssetLocation]
    let reserveIdOverrides: [ChainModel.Id: [AssetIdKey: AssetLocationId]]
    let chains: [XcmDynamicChain]

    func transfer(
        from chainAssetId: ChainAssetId,
        destinationChainId: ChainModel.Id
    ) -> XcmDynamicAssetTransfer? {
        guard
            let chain = chains.first(where: { $0.chainId == chainAssetId.chainId }),
            let xcmTransfers = chain.assets.first(where: { $0.assetId == chainAssetId.assetId })?.xcmTransfers else {
            return nil
        }

        return xcmTransfers.first { $0.chainId == destinationChainId }
    }

    func getReservePath(for chainAsset: ChainAsset) -> XcmAsset.ReservePath? {
        let chainId = chainAsset.chain.chainId
        let assetIdKey = String(chainAsset.asset.assetId)

        let overridenLocation = reserveIdOverrides[chainId]?[assetIdKey]
        let assetLocationId = overridenLocation ?? chainAsset.asset.symbol

        guard let path = assetsLocation[assetLocationId]?.multiLocation else {
            return nil
        }

        return XcmAsset.ReservePath(type: .relative, path: path)
    }

    func getReserveChainId(for chainAsset: ChainAsset) -> ChainModel.Id? {
        let chainId = chainAsset.chain.chainId
        let assetIdKey = String(chainAsset.asset.assetId)

        let assetLocationId = reserveIdOverrides[chainId]?[assetIdKey] ?? chainAsset.asset.symbol

        return assetsLocation[assetLocationId]?.chainId?.stringValue
    }
}
