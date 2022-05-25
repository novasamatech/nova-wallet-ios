import Foundation
import CoreData
import RobinHood
import SubstrateSdk

final class ChainModelMapper {
    var entityIdentifierFieldName: String { #keyPath(CDChain.chainId) }

    typealias DataProviderModel = ChainModel
    typealias CoreDataEntity = CDChain

    private lazy var jsonEncoder = JSONEncoder()
    private lazy var jsonDecoder = JSONDecoder()

    private func createAsset(from entity: CDAsset) throws -> AssetModel {
        let typeExtras: JSON?

        if let data = entity.typeExtras {
            typeExtras = try jsonDecoder.decode(JSON.self, from: data)
        } else {
            typeExtras = nil
        }

        let buyProviders: JSON?

        if let data = entity.buyProviders {
            buyProviders = try jsonDecoder.decode(JSON.self, from: data)
        } else {
            buyProviders = nil
        }

        return AssetModel(
            assetId: UInt32(bitPattern: entity.assetId),
            icon: entity.icon,
            name: entity.name,
            symbol: entity.symbol!,
            precision: UInt16(bitPattern: entity.precision),
            priceId: entity.priceId,
            staking: entity.staking,
            type: entity.type,
            typeExtras: typeExtras,
            buyProviders: buyProviders
        )
    }

    private func createChainNode(from entity: CDChainNode) -> ChainNodeModel {
        let apiKey: ChainNodeModel.ApiKey?

        if let queryName = entity.apiQueryName, let keyName = entity.apiKeyName {
            apiKey = ChainNodeModel.ApiKey(queryName: queryName, keyName: keyName)
        } else {
            apiKey = nil
        }

        return ChainNodeModel(
            url: entity.url!,
            name: entity.name!,
            apikey: apiKey,
            order: entity.order
        )
    }

    private func updateEntityAssets(
        for entity: CDChain,
        from model: ChainModel,
        context: NSManagedObjectContext
    ) throws {
        let assetEntities: [CDAsset] = try model.assets.map { asset in
            let assetEntity: CDAsset
            let assetEntityId = Int32(bitPattern: asset.assetId)

            let maybeExistingEntity = entity.assets?
                .first { ($0 as? CDAsset)?.assetId == assetEntityId } as? CDAsset

            if let existingEntity = maybeExistingEntity {
                assetEntity = existingEntity
            } else {
                assetEntity = CDAsset(context: context)
            }

            assetEntity.assetId = assetEntityId
            assetEntity.name = asset.name
            assetEntity.precision = Int16(bitPattern: asset.precision)
            assetEntity.icon = asset.icon
            assetEntity.symbol = asset.symbol
            assetEntity.priceId = asset.priceId
            assetEntity.staking = asset.staking
            assetEntity.type = asset.type

            if let json = asset.typeExtras {
                assetEntity.typeExtras = try jsonEncoder.encode(json)
            } else {
                assetEntity.typeExtras = nil
            }

            if let json = asset.buyProviders {
                assetEntity.buyProviders = try jsonEncoder.encode(json)
            } else {
                assetEntity.buyProviders = nil
            }

            return assetEntity
        }

        let existingAssetIds = Set(model.assets.map(\.assetId))

        if let oldAssets = entity.assets as? Set<CDAsset> {
            for oldAsset in oldAssets {
                if !existingAssetIds.contains(UInt32(bitPattern: oldAsset.assetId)) {
                    context.delete(oldAsset)
                }
            }
        }

        entity.assets = Set(assetEntities) as NSSet
    }

    private func updateEntityNodes(
        for entity: CDChain,
        from model: ChainModel,
        context: NSManagedObjectContext
    ) {
        let nodeEntities: [CDChainNode] = model.nodes.map { node in
            let nodeEntity: CDChainNode

            let maybeExistingEntity = entity.nodes?
                .first { ($0 as? CDChainNode)?.url == node.url } as? CDChainNode

            if let existingEntity = maybeExistingEntity {
                nodeEntity = existingEntity
            } else {
                nodeEntity = CDChainNode(context: context)
            }

            nodeEntity.url = node.url
            nodeEntity.name = node.name
            nodeEntity.apiQueryName = node.apikey?.queryName
            nodeEntity.apiKeyName = node.apikey?.keyName
            nodeEntity.order = node.order

            return nodeEntity
        }

        let existingNodeIds = Set(model.nodes.map(\.url))

        if let oldNodes = entity.nodes as? Set<CDChainNode> {
            for oldNode in oldNodes {
                if !existingNodeIds.contains(oldNode.url!) {
                    context.delete(oldNode)
                }
            }
        }

        entity.nodes = Set(nodeEntities) as NSSet
    }

    private func createExplorers(from chain: CDChain) -> [ChainModel.Explorer]? {
        guard let data = chain.explorers else {
            return nil
        }

        return try? JSONDecoder().decode([ChainModel.Explorer].self, from: data)
    }

    private func updateExplorers(for entity: CDChain, from explorers: [ChainModel.Explorer]?) {
        if let explorers = explorers {
            entity.explorers = try? JSONEncoder().encode(explorers)
        } else {
            entity.explorers = nil
        }
    }

    private func createExternalApi(from entity: CDChain) -> ChainModel.ExternalApiSet? {
        let staking: ChainModel.ExternalApi?

        if let type = entity.stakingApiType, let url = entity.stakingApiUrl {
            staking = ChainModel.ExternalApi(type: type, url: url)
        } else {
            staking = nil
        }

        let history: ChainModel.ExternalApi?

        if let type = entity.historyApiType, let url = entity.historyApiUrl {
            history = ChainModel.ExternalApi(type: type, url: url)
        } else {
            history = nil
        }

        let crowdloans: ChainModel.ExternalApi?

        if let type = entity.crowdloansApiType, let url = entity.crowdloansApiUrl {
            crowdloans = ChainModel.ExternalApi(type: type, url: url)
        } else {
            crowdloans = nil
        }

        if staking != nil || history != nil || crowdloans != nil {
            return ChainModel.ExternalApiSet(staking: staking, history: history, crowdloans: crowdloans)
        } else {
            return nil
        }
    }

    private func updateExternalApis(in entity: CDChain, from apis: ChainModel.ExternalApiSet?) {
        entity.stakingApiType = apis?.staking?.type
        entity.stakingApiUrl = apis?.staking?.url

        entity.historyApiType = apis?.history?.type
        entity.historyApiUrl = apis?.history?.url

        entity.crowdloansApiType = apis?.crowdloans?.type
        entity.crowdloansApiUrl = apis?.crowdloans?.url
    }
}

extension ChainModelMapper: CoreDataMapperProtocol {
    func transform(entity: CDChain) throws -> ChainModel {
        let assets: [AssetModel] = try entity.assets?.compactMap { anyAsset in
            guard let asset = anyAsset as? CDAsset else {
                return nil
            }

            return try createAsset(from: asset)
        } ?? []

        let nodes: [ChainNodeModel] = entity.nodes?.compactMap { anyNode in
            guard let node = anyNode as? CDChainNode else {
                return nil
            }

            return createChainNode(from: node)
        } ?? []

        let types: ChainModel.TypesSettings?

        if let url = entity.types, let overridesCommon = entity.typesOverrideCommon {
            types = .init(url: url, overridesCommon: overridesCommon.boolValue)
        } else {
            types = nil
        }

        var options: [ChainOptions] = []

        if entity.isEthereumBased {
            options.append(.ethereumBased)
        }

        if entity.isTestnet {
            options.append(.testnet)
        }

        if entity.hasCrowdloans {
            options.append(.crowdloans)
        }

        let externalApiSet = createExternalApi(from: entity)
        let explorers = createExplorers(from: entity)

        let additional: JSON? = try entity.additional.map {
            try jsonDecoder.decode(JSON.self, from: $0)
        }

        return ChainModel(
            chainId: entity.chainId!,
            parentId: entity.parentId,
            name: entity.name!,
            assets: Set(assets),
            nodes: Set(nodes),
            addressPrefix: UInt16(bitPattern: entity.addressPrefix),
            types: types,
            icon: entity.icon!,
            color: entity.color,
            options: options.isEmpty ? nil : options,
            externalApi: externalApiSet,
            explorers: explorers,
            order: entity.order,
            additional: additional
        )
    }

    func populate(
        entity: CDChain,
        from model: ChainModel,
        using context: NSManagedObjectContext
    ) throws {
        entity.chainId = model.chainId
        entity.parentId = model.parentId
        entity.name = model.name
        entity.types = model.types?.url
        entity.typesOverrideCommon = model.types.map { NSNumber(value: $0.overridesCommon) }

        entity.addressPrefix = Int16(bitPattern: model.addressPrefix)
        entity.icon = model.icon
        entity.color = model.color
        entity.isEthereumBased = model.isEthereumBased
        entity.isTestnet = model.isTestnet
        entity.hasCrowdloans = model.hasCrowdloans
        entity.order = model.order
        entity.additional = try model.additional.map {
            try jsonEncoder.encode($0)
        }

        try updateEntityAssets(for: entity, from: model, context: context)

        updateEntityNodes(for: entity, from: model, context: context)

        updateExternalApis(in: entity, from: model.externalApi)

        updateExplorers(for: entity, from: model.explorers)
    }
}
