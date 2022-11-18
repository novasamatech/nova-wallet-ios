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

    struct ExternalApi: Codable, Hashable {
        let type: String
        let url: URL
    }

    struct ExternalApiSet: Codable, Hashable {
        let staking: ExternalApi?
        let history: ExternalApi?
        let crowdloans: ExternalApi?
        let governance: ExternalApi?
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
    let externalApi: ExternalApiSet?
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
        externalApi: ExternalApiSet?,
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
        self.externalApi = externalApi
        self.explorers = explorers
        self.order = order
        self.additional = additional
    }

    init(remoteModel: RemoteChainModel, order: Int64) {
        chainId = remoteModel.chainId
        parentId = remoteModel.parentId
        name = remoteModel.name
        assets = Set(remoteModel.assets)

        let nodeList = remoteModel.nodes.enumerated().map { index, node in
            ChainNodeModel(remoteModel: node, order: Int16(index))
        }

        nodes = Set(nodeList)

        addressPrefix = remoteModel.addressPrefix
        types = remoteModel.types
        icon = remoteModel.icon
        options = remoteModel.options?.compactMap { ChainOptions(rawValue: $0) }
        externalApi = remoteModel.externalApi
        explorers = remoteModel.explorers
        additional = remoteModel.additional

        self.order = order
    }

    func asset(for assetId: AssetModel.Id) -> AssetModel? {
        assets.first { $0.assetId == assetId }
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
}

extension ChainModel {
    init(remoteModel: RemoteChainModel, additionalAssets: Set<AssetModel>, order: Int64) {
        let chain = ChainModel(remoteModel: remoteModel, order: order)
        chainId = chain.chainId
        parentId = chain.parentId
        name = chain.name
        assets = chain.assets.union(additionalAssets)
        nodes = chain.nodes
        addressPrefix = chain.addressPrefix
        types = chain.types
        icon = chain.icon
        options = chain.options
        externalApi = chain.externalApi
        explorers = chain.explorers
        self.order = chain.order
        additional = chain.additional
    }
}
