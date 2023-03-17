import Foundation
import RobinHood
import SubstrateSdk
import BigInt

struct ChainModel: Equatable, Codable, Hashable {
    // swiftlint:disable:next type_name
    typealias Id = String

    struct TypesSettings: Codable, Hashable {
        let url: URL
        let overridesCommon: Bool
    }

    struct Explorer: Codable, Hashable {
        let name: String
        let account: String?
        let extrinsic: String?
        let event: String?
    }

    enum TypesUsage {
        case onlyCommon
        case both
        case onlyOwn
    }

    let chainId: Id
    let parentId: Id?
    let name: String
    let assets: Set<AssetModel>
    let nodes: Set<ChainNodeModel>
    let addressPrefix: UInt16
    let types: TypesSettings?
    let icon: URL
    let options: [ChainOptions]?
    let externalApis: LocalChainExternalApiSet?
    let explorers: [Explorer]?
    let order: Int64
    let additional: JSON?

    init(
        chainId: Id,
        parentId: Id?,
        name: String,
        assets: Set<AssetModel>,
        nodes: Set<ChainNodeModel>,
        addressPrefix: UInt16,
        types: TypesSettings?,
        icon: URL,
        options: [ChainOptions]?,
        externalApis: LocalChainExternalApiSet?,
        explorers: [Explorer]?,
        order: Int64,
        additional: JSON?
    ) {
        self.chainId = chainId
        self.parentId = parentId
        self.name = name
        self.assets = assets
        self.nodes = nodes
        self.addressPrefix = addressPrefix
        self.types = types
        self.icon = icon
        self.options = options
        self.externalApis = externalApis
        self.explorers = explorers
        self.order = order
        self.additional = additional
    }

    init(remoteModel: RemoteChainModel, assets: Set<AssetModel>, order: Int64) {
        chainId = remoteModel.chainId
        parentId = remoteModel.parentId
        name = remoteModel.name
        self.assets = assets

        let nodeList = remoteModel.nodes.enumerated().map { index, node in
            ChainNodeModel(remoteModel: node, order: Int16(index))
        }

        nodes = Set(nodeList)

        addressPrefix = remoteModel.addressPrefix
        types = remoteModel.types
        icon = remoteModel.icon
        options = remoteModel.options?.compactMap { ChainOptions(rawValue: $0) }
        externalApis = remoteModel.externalApi.map { LocalChainExternalApiSet(remoteApi: $0) }
        explorers = remoteModel.explorers
        additional = remoteModel.additional

        self.order = order
    }

    func asset(for assetId: AssetModel.Id) -> AssetModel? {
        assets.first { $0.assetId == assetId }
    }

    func hasEnabledAsset() -> Bool {
        assets.contains { $0.enabled }
    }

    var isEthereumBased: Bool {
        options?.contains(.ethereumBased) ?? false
    }

    var isTestnet: Bool {
        options?.contains(.testnet) ?? false
    }

    var hasCrowdloans: Bool {
        options?.contains(.crowdloans) ?? false
    }

    var hasGovernance: Bool {
        options?.contains(where: { $0 == .governance || $0 == .governanceV1 }) ?? false
    }

    var hasGovernanceV1: Bool {
        options?.contains(where: { $0 == .governanceV1 }) ?? false
    }

    var hasGovernanceV2: Bool {
        options?.contains(where: { $0 == .governance }) ?? false
    }

    var noSubstrateRuntime: Bool {
        options?.contains(where: { $0 == .noSubstrateRuntime }) ?? false
    }

    var isRelaychain: Bool { parentId == nil }

    func utilityAssets() -> Set<AssetModel> {
        assets.filter { $0.isUtility }
    }

    func utilityAsset() -> AssetModel? {
        utilityAssets().first
    }

    func utilityAssetDisplayInfo() -> AssetBalanceDisplayInfo? {
        utilityAsset()?.displayInfo(with: icon)
    }

    func utilityChainAssetId() -> ChainAssetId? {
        guard let utilityAsset = utilityAssets().first else {
            return nil
        }

        return ChainAssetId(chainId: chainId, assetId: utilityAsset.assetId)
    }

    var typesUsage: TypesUsage {
        if let types = types {
            return types.overridesCommon ? .onlyOwn : .both
        } else {
            return .onlyCommon
        }
    }

    var defaultTip: BigUInt? {
        if let tipString = additional?.defaultTip?.stringValue {
            return BigUInt(tipString)
        } else {
            return nil
        }
    }
}

extension ChainModel: Identifiable {
    var identifier: String { chainId }
}

enum ChainOptions: String, Codable {
    case ethereumBased
    case testnet
    case crowdloans
    case governance
    case governanceV1 = "governance-v1"
    case noSubstrateRuntime
}

extension ChainModel {
    func adding(asset: AssetModel) -> ChainModel {
        .init(
            chainId: chainId,
            parentId: parentId,
            name: name,
            assets: assets.union([asset]),
            nodes: nodes,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional
        )
    }

    func byChanging(assets: Set<AssetModel>? = nil, name: String? = nil) -> ChainModel {
        let newAssets = assets ?? self.assets
        let newName = name ?? self.name

        return .init(
            chainId: chainId,
            parentId: parentId,
            name: newName,
            assets: newAssets,
            nodes: nodes,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional
        )
    }
}
