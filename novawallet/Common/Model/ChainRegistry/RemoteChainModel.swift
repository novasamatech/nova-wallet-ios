import Foundation
import RobinHood
import SubstrateSdk

struct RemoteChainModel: Equatable, Codable, Hashable {
    let chainId: ChainModel.Id
    let parentId: ChainModel.Id?
    let name: String
    let assets: [AssetModel]
    let nodes: [RemoteChainNodeModel]
    let addressPrefix: UInt16
    let types: ChainModel.TypesSettings?
    let icon: URL
    let color: String?
    let options: [ChainOptions]?
    let externalApi: ChainModel.ExternalApiSet?
    let explorers: [ChainModel.Explorer]?
    let additional: JSON?
}
