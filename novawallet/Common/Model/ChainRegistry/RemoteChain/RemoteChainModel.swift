import Foundation
import RobinHood
import SubstrateSdk

struct RemoteChainModel: Equatable, Codable, Hashable {
    let chainId: ChainModel.Id
    let parentId: ChainModel.Id?
    let name: String
    let assets: [RemoteAssetModel]
    let nodes: [RemoteChainNodeModel]
    let addressPrefix: UInt16
    let types: ChainModel.TypesSettings?
    let icon: URL
    let options: [String]?
    let externalApi: RemoteChainExternalApiSet?
    let explorers: [ChainModel.Explorer]?
    let additional: JSON?
}

extension RemoteChainModel {
    func byChanging(name: String) -> RemoteChainModel {
        .init(
            chainId: chainId,
            parentId: parentId,
            name: name,
            assets: assets,
            nodes: nodes,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApi: externalApi,
            explorers: explorers,
            additional: additional
        )
    }
}
