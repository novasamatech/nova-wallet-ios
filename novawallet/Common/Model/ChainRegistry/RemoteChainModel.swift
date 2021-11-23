import Foundation
import RobinHood

struct RemoteChainModel: Equatable, Codable, Hashable {
    let chainId: ChainModel.Id
    let parentId: ChainModel.Id?
    let name: String
    let assets: [AssetModel]
    let nodes: [RemoteChainNodeModel]
    let addressPrefix: UInt16
    let types: ChainModel.TypesSettings?
    let icon: URL
    let options: [ChainOptions]?
    let externalApi: ChainModel.ExternalApiSet?
    let explorers: [ChainModel.Explorer]?
}
