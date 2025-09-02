import Foundation
import Operation_iOS
import SubstrateSdk

struct RemoteChainModel: Equatable, Codable {
    let chainId: ChainModel.Id
    let parentId: ChainModel.Id?
    let name: String
    let assets: [RemoteAssetModel]
    let nodes: [RemoteChainNodeModel]
    let nodeSelectionStrategy: String?
    let addressPrefix: ChainModel.AddressPrefix
    let legacyAddressPrefix: ChainModel.AddressPrefix?
    let types: ChainModel.TypesSettings?
    let icon: URL?
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
            nodeSelectionStrategy: nodeSelectionStrategy,
            addressPrefix: addressPrefix,
            legacyAddressPrefix: legacyAddressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApi: externalApi,
            explorers: explorers,
            additional: additional
        )
    }
}

enum RemoteOnlyChainOptions: String {
    case fullSyncByDefault
}
