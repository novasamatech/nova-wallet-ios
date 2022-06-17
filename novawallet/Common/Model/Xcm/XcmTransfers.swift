import Foundation
import SubstrateSdk

struct XcmTransfers: Decodable {
    let assetsLocation: [String: JSON]
    let instructions: [String: [String]]
    let chains: [XcmChain]

    func assetLocation(for key: String) -> JSON? {
        assetsLocation[key]
    }

    func instructions(for key: String) -> [String]? {
        instructions[key]
    }

    func transferableAssetIds(from chainId: ChainModel.Id) -> Set<AssetModel.Id> {
        guard let chain = chains.first(where: { $0.chainId == chainId }) else {
            return Set()
        }

        let assetIds = chain.assets.map(\.assetId)
        return Set(assetIds)
    }

    func getReserveTransfering(from chainId: ChainModel.Id, assetId: AssetModel.Id) -> ChainModel.Id? {
        guard
            let chain = chains.first(where: { $0.chainId == chainId }),
            let asset = chain.assets.first(where: { $0.assetId == assetId }),
            let assetLocation = assetsLocation[asset.assetLocation] else {
            return nil
        }

        return assetLocation.chainId?.stringValue
    }

    func transfers(from chainId: ChainModel.Id, assetId: AssetModel.Id) -> [XcmAssetTransfer] {
        guard
            let chain = chains.first(where: { $0.chainId == chainId }),
            let xcmTransfers = chain.assets.first(where: { $0.assetId == assetId })?.xcmTransfers else {
            return []
        }

        return xcmTransfers
    }
}
