import Foundation

struct PartialCustomChainModel: ChainNodeConnectable, RuntimeProviderChainProtocol {
    let chainId: String
    let url: String
    let name: String
    let iconUrl: URL?
    let assets: Set<AssetModel>
    let nodes: Set<ChainNodeModel>
    let currencySymbol: String?
    let options: [LocalChainOptions]?
    let nodeSwitchStrategy: ChainModel.NodeSwitchStrategy
    let addressPrefix: UInt16
    let connectionMode: ChainModel.ConnectionMode
    let blockExplorer: ChainModel.Explorer?
    let mainAssetPriceId: AssetModel.PriceId?

    let typesUsage: ChainModel.TypesUsage = .none

    func adding(_ asset: AssetModel) -> PartialCustomChainModel {
        PartialCustomChainModel(
            chainId: chainId,
            url: url,
            name: name,
            iconUrl: iconUrl,
            assets: assets.union([asset]),
            nodes: nodes,
            currencySymbol: currencySymbol,
            options: options,
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix,
            connectionMode: connectionMode,
            blockExplorer: blockExplorer,
            mainAssetPriceId: mainAssetPriceId
        )
    }

    func adding(_ options: [LocalChainOptions]) -> PartialCustomChainModel {
        let updatedOptions = if let oldOptions = self.options {
            Array(Set(oldOptions).union(Set(options)))
        } else {
            options
        }

        return PartialCustomChainModel(
            chainId: chainId,
            url: url,
            name: name,
            iconUrl: iconUrl,
            assets: assets,
            nodes: nodes,
            currencySymbol: currencySymbol,
            options: updatedOptions,
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix,
            connectionMode: connectionMode,
            blockExplorer: blockExplorer,
            mainAssetPriceId: mainAssetPriceId
        )
    }

    func byChanging(addressPrefix: UInt16?) -> PartialCustomChainModel {
        PartialCustomChainModel(
            chainId: chainId,
            url: url,
            name: name,
            iconUrl: iconUrl,
            assets: assets,
            nodes: nodes,
            currencySymbol: currencySymbol,
            options: options,
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix ?? self.addressPrefix,
            connectionMode: connectionMode,
            blockExplorer: blockExplorer,
            mainAssetPriceId: mainAssetPriceId
        )
    }

    func byChanging(chainId: ChainModel.Id) -> PartialCustomChainModel {
        PartialCustomChainModel(
            chainId: chainId,
            url: url,
            name: name,
            iconUrl: iconUrl,
            assets: assets,
            nodes: nodes,
            currencySymbol: currencySymbol,
            options: options,
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix,
            connectionMode: connectionMode,
            blockExplorer: blockExplorer,
            mainAssetPriceId: mainAssetPriceId
        )
    }

    func byChanging(name: String) -> PartialCustomChainModel {
        PartialCustomChainModel(
            chainId: chainId,
            url: url,
            name: name,
            iconUrl: iconUrl,
            assets: assets,
            nodes: nodes,
            currencySymbol: currencySymbol,
            options: options,
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix,
            connectionMode: connectionMode,
            blockExplorer: blockExplorer,
            mainAssetPriceId: mainAssetPriceId
        )
    }
}
