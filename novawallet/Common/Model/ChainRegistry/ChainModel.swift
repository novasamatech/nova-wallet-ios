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
    let color: String?
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
        color: String?,
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
        self.color = color
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
        options = remoteModel.options
        externalApi = remoteModel.externalApi
        explorers = remoteModel.explorers
        color = remoteModel.color
        additional = remoteModel.additional

        self.order = order
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

    var isRelaychain: Bool { parentId == nil }

    func utilityAssets() -> Set<AssetModel> {
        assets.filter { $0.isUtility }
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
}
