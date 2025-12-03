import Foundation

struct RemoteChainsModel: Codable {
    let assetDisplayPriorities: [AssetModel.Symbol: UInt8]
    let chainDisplayPriorities: [ChainModel.Id: UInt8]
    let chains: [RemoteChainModel]
}
