import Foundation

struct RemoteChainsModel: Codable {
    let assetDisplayPriorities: [AssetModel.Symbol: UInt16]
    let chainDisplayPriorities: [ChainModel.Id: UInt16]
    let chains: [RemoteChainModel]
}
