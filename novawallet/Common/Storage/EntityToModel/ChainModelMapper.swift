import Foundation
import CoreData
import RobinHood
import SubstrateSdk

enum ChainModelMapperError: Error {
    case unexpectedSyncMode(Int16)
}

final class ChainModelMapper {
    var entityIdentifierFieldName: String { #keyPath(CDChain.chainId) }

    typealias DataProviderModel = ChainModel
    typealias CoreDataEntity = CDChain

    private lazy var jsonEncoder = JSONEncoder()
    private lazy var jsonDecoder = JSONDecoder()

    private func createNodeFeatures(from entityData: Data?) throws -> Set<ChainNodeModel.Feature>? {
        let featureList = try entityData.flatMap { try jsonDecoder.decode([String].self, from: $0) }

        return featureList.flatMap { Set($0.compactMap { .init(rawValue: $0) }) }
    }

    private func serializeNodeFeature(from model: Set<ChainNodeModel.Feature>?) throws -> Data? {
        try model.flatMap { try jsonEncoder.encode($0) }
    }

    private func createStakings(from entity: CDAsset) throws -> [StakingType]? {
        guard let staking = entity.staking else {
            return nil
        }

        let rawStakings = staking.split(by: String.Separator.comma)

        return rawStakings.map { StakingType(rawType: $0) }
    }

    private func updateStakings(on entity: CDAsset, newStakings: [StakingType]?) throws {
        let rawStakings = newStakings?.map(\.rawValue).joined(with: String.Separator.comma)
        entity.staking = rawStakings
    }

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

        let source = AssetModel.Source(rawValue: entity.source!) ?? .remote

        let stakings = try createStakings(from: entity)

        return AssetModel(
            assetId: UInt32(bitPattern: entity.assetId),
            icon: entity.icon,
            name: entity.name,
            symbol: entity.symbol!,
            precision: UInt16(bitPattern: entity.precision),
            priceId: entity.priceId,
            stakings: stakings,
            type: entity.type,
            typeExtras: typeExtras,
            buyProviders: buyProviders,
            enabled: entity.enabled,
            source: source
        )
    }

    private func createChainNode(from entity: CDChainNodeItem) throws -> ChainNodeModel {
        let features = try createNodeFeatures(from: entity.features)

        return ChainNodeModel(
            url: entity.url!,
            name: entity.name!,
            order: entity.order,
            features: features
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
            assetEntity.type = asset.type
            assetEntity.enabled = asset.enabled
            assetEntity.source = asset.source.rawValue

            try updateStakings(on: assetEntity, newStakings: asset.stakings)

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
    ) throws {
        let nodeEntities: [CDChainNodeItem] = try model.nodes.map { node in
            let nodeEntity: CDChainNodeItem

            let maybeExistingEntity = entity.nodes?
                .first { ($0 as? CDChainNodeItem)?.url == node.url } as? CDChainNodeItem

            if let existingEntity = maybeExistingEntity {
                nodeEntity = existingEntity
            } else {
                nodeEntity = CDChainNodeItem(context: context)
            }

            nodeEntity.url = node.url
            nodeEntity.name = node.name
            nodeEntity.order = node.order
            nodeEntity.features = try serializeNodeFeature(from: node.features)

            return nodeEntity
        }

        let existingNodeIds = Set(model.nodes.map(\.url))

        if let oldNodes = entity.nodes as? Set<CDChainNodeItem> {
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

    private func createExternalApis(from entityApis: NSSet?) -> LocalChainExternalApiSet? {
        guard let entityApis = entityApis as? Set<CDChainApi>, !entityApis.isEmpty else {
            return nil
        }

        let apis = entityApis.map {
            let parameters: JSON?

            if let rawParameters = $0.parameters {
                parameters = try? jsonDecoder.decode(JSON.self, from: rawParameters)
            } else {
                parameters = nil
            }

            return LocalChainExternalApi(
                apiType: $0.apiType!,
                serviceType: $0.serviceType!,
                url: $0.url!,
                parameters: parameters
            )
        }

        return .init(localApis: Set(apis))
    }

    private func updateExternalApis(
        for entity: CDChain,
        from model: ChainModel,
        context: NSManagedObjectContext
    ) {
        let optApiEntities: [CDChainApi]? = model.externalApis?.apis.map { apiModel in
            let apiEntity: CDChainApi

            let maybeExistingEntity = entity.externalApis?.first { entity in
                guard let entity = entity as? CDChainApi else {
                    return false
                }

                return entity.identifier == apiModel.identifier
            } as? CDChainApi

            if let existingEntity = maybeExistingEntity {
                apiEntity = existingEntity
            } else {
                apiEntity = CDChainApi(context: context)
            }

            apiEntity.apiType = apiModel.apiType
            apiEntity.url = apiModel.url
            apiEntity.serviceType = apiModel.serviceType

            if let parameters = apiModel.parameters {
                apiEntity.parameters = try? jsonEncoder.encode(parameters)
            } else {
                apiEntity.parameters = nil
            }

            return apiEntity
        }

        let existingApiEntities = Set((model.externalApis?.apis ?? []).map(\.identifier))

        if let oldApis = entity.externalApis as? Set<CDChainApi> {
            for oldApi in oldApis {
                if !existingApiEntities.contains(oldApi.identifier) {
                    context.delete(oldApi)
                }
            }
        }

        if let apiEntities = optApiEntities {
            entity.externalApis = Set(apiEntities) as NSSet
        } else {
            entity.externalApis = nil
        }
    }

    private func createChainOptions(from entity: CDChain) -> [LocalChainOptions]? {
        var options: [LocalChainOptions] = []

        if entity.isEthereumBased {
            options.append(.ethereumBased)
        }

        if entity.isTestnet {
            options.append(.testnet)
        }

        if entity.hasCrowdloans {
            options.append(.crowdloans)
        }

        if entity.hasGovernance {
            options.append(.governance)
        }

        if entity.hasGovernanceV1 {
            options.append(.governanceV1)
        }

        if entity.noSubstrateRuntime {
            options.append(.noSubstrateRuntime)
        }

        if entity.hasSwapHub {
            options.append(.swapHub)
        }

        if entity.hasSwapHydra {
            options.append(.swapHydra)
        }

        if entity.hasProxy {
            options.append(.proxy)
        }

        return !options.isEmpty ? options : nil
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

        let nodes: [ChainNodeModel] = try entity.nodes?.compactMap { anyNode in
            guard let node = anyNode as? CDChainNodeItem else {
                return nil
            }

            return try createChainNode(from: node)
        } ?? []

        let nodeSwitchStrategy = ChainModel.NodeSwitchStrategy(rawStrategy: entity.nodeSwitchStrategy)

        let types: ChainModel.TypesSettings?

        if entity.types != nil || entity.typesOverrideCommon != nil {
            types = .init(url: entity.types, overridesCommon: entity.typesOverrideCommon?.boolValue ?? false)
        } else {
            types = nil
        }

        let externalApiSet = createExternalApis(from: entity.externalApis)
        let explorers = createExplorers(from: entity)

        let options = createChainOptions(from: entity)

        let additional: JSON? = try entity.additional.map {
            try jsonDecoder.decode(JSON.self, from: $0)
        }

        guard let syncMode = ChainSyncMode(entityValue: entity.syncMode) else {
            throw ChainModelMapperError.unexpectedSyncMode(entity.syncMode)
        }

        return ChainModel(
            chainId: entity.chainId!,
            parentId: entity.parentId,
            name: entity.name!,
            assets: Set(assets),
            nodes: Set(nodes),
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: UInt16(bitPattern: entity.addressPrefix),
            types: types,
            icon: entity.icon!,
            options: options,
            externalApis: externalApiSet,
            explorers: explorers,
            order: entity.order,
            additional: additional,
            syncMode: syncMode
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
        entity.isEthereumBased = model.isEthereumBased
        entity.isTestnet = model.isTestnet
        entity.hasCrowdloans = model.hasCrowdloans
        entity.hasGovernanceV1 = model.hasGovernanceV1
        entity.hasGovernance = model.hasGovernanceV2
        entity.noSubstrateRuntime = model.noSubstrateRuntime
        entity.hasSwapHub = model.hasSwapHub
        entity.hasSwapHydra = model.hasSwapHydra
        entity.hasProxy = model.hasProxy
        entity.order = model.order
        entity.nodeSwitchStrategy = model.nodeSwitchStrategy.rawValue
        entity.additional = try model.additional.map {
            try jsonEncoder.encode($0)
        }

        entity.syncMode = model.syncMode.toEntityValue()

        try updateEntityAssets(for: entity, from: model, context: context)

        try updateEntityNodes(for: entity, from: model, context: context)

        updateExternalApis(for: entity, from: model, context: context)

        updateExplorers(for: entity, from: model.explorers)
    }
}
