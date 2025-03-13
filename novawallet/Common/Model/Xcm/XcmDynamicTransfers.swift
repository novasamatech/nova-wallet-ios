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
}
