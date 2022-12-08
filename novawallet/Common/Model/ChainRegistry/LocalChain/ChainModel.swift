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

    struct TransactionHistoryApi: Codable, Hashable {
        let serviceType: String
        let url: URL
        let assetType: String?

        init(
            serviceType: String,
            url: URL,
            assetType: String?
        ) {
            self.serviceType = serviceType
            self.url = url
            self.assetType = assetType
        }

        init(remoteModel: RemoteTransactionHistoryApi) {
            serviceType = remoteModel.type
            url = remoteModel.url
            assetType = remoteModel.assetType
        }
    }

    struct ExternalApiSet: Codable, Hashable {
        let staking: ExternalApi?
        let history: Set<TransactionHistoryApi>?
        let crowdloans: ExternalApi?
        let governance: ExternalApi?

        init(
            staking: ExternalApi?,
            history: Set<TransactionHistoryApi>?,
            crowdloans: ExternalApi?,
            governance: ExternalApi?
        ) {
            self.staking = staking
            self.history = history
            self.crowdloans = crowdloans
            self.governance = governance
        }

        init(remoteModel: RemoteChainExternalApiSet) {
            staking = remoteModel.staking
            crowdloans = remoteModel.crowdloans
            governance = remoteModel.governance

            let optHistoryApis = remoteModel.history?.map {
                TransactionHistoryApi(remoteModel: $0)
            }

            if let historyApis = optHistoryApis {
                history = Set(historyApis)
            } else {
                history = nil
            }
        }
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
        externalApi = remoteModel.externalApi.map { ExternalApiSet(remoteModel: $0) }
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
            externalApi: externalApi,
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
            externalApi: externalApi,
            explorers: explorers,
            order: order,
            additional: additional
        )
    }
}
