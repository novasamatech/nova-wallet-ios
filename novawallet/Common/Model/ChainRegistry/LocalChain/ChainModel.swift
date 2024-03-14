import Foundation
import RobinHood
import SubstrateSdk
import BigInt

struct ChainModel: Equatable, Hashable {
    // swiftlint:disable:next type_name
    typealias Id = String

    struct TypesSettings: Codable, Hashable {
        let url: URL?
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
        case none
    }

    enum NodeSwitchStrategy: String, Codable, Hashable {
        case uniform
        case roundRobin

        init(rawStrategy: String?) {
            self = rawStrategy.flatMap { .init(rawValue: $0) } ?? .roundRobin
        }
    }

    let chainId: Id
    let parentId: Id?
    let name: String
    let assets: Set<AssetModel>
    let nodes: Set<ChainNodeModel>
    let addressPrefix: UInt16
    let types: TypesSettings?
    let icon: URL
    let options: [LocalChainOptions]?
    let externalApis: LocalChainExternalApiSet?
    let nodeSwitchStrategy: NodeSwitchStrategy
    let explorers: [Explorer]?
    let order: Int64
    let additional: JSON?
    let syncMode: ChainSyncMode

    init(
        chainId: Id,
        parentId: Id?,
        name: String,
        assets: Set<AssetModel>,
        nodes: Set<ChainNodeModel>,
        nodeSwitchStrategy: NodeSwitchStrategy,
        addressPrefix: UInt16,
        types: TypesSettings?,
        icon: URL,
        options: [LocalChainOptions]?,
        externalApis: LocalChainExternalApiSet?,
        explorers: [Explorer]?,
        order: Int64,
        additional: JSON?,
        syncMode: ChainSyncMode
    ) {
        self.chainId = chainId
        self.parentId = parentId
        self.name = name
        self.assets = assets
        self.nodes = nodes
        self.nodeSwitchStrategy = nodeSwitchStrategy
        self.addressPrefix = addressPrefix
        self.types = types
        self.icon = icon
        self.options = options
        self.externalApis = externalApis
        self.explorers = explorers
        self.order = order
        self.additional = additional
        self.syncMode = syncMode
    }

    func asset(for assetId: AssetModel.Id) -> AssetModel? {
        assets.first { $0.assetId == assetId }
    }

    func assetOrNil(for assetId: AssetModel.Id?) -> AssetModel? {
        guard let assetId = assetId else {
            return nil
        }

        return assets.first { $0.assetId == assetId }
    }

    func assetOrNative(for assetId: AssetModel.Id?) -> AssetModel? {
        guard let assetId = assetId else {
            return utilityAsset()
        }

        return assets.first { $0.assetId == assetId }
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

    var hasSwapHub: Bool {
        options?.contains(where: { $0 == .swapHub }) ?? false
    }

    var hasSwapHydra: Bool {
        options?.contains(where: { $0 == .swapHydra }) ?? false
    }

    var hasSwaps: Bool {
        hasSwapHub || hasSwapHydra
    }

    var hasProxy: Bool {
        options?.contains(where: { $0 == .proxy }) ?? false
    }

    var noSubstrateRuntime: Bool {
        options?.contains(where: { $0 == .noSubstrateRuntime }) ?? false
    }

    var hasSubstrateRuntime: Bool {
        !noSubstrateRuntime
    }

    var hasStaking: Bool {
        assets.contains { $0.hasStaking }
    }

    func chainAssetsWithExternalBalances() -> [ChainAsset] {
        assets.compactMap { asset in
            guard asset.hasPoolStaking || asset.isUtility && hasCrowdloans else {
                return nil
            }

            return ChainAsset(chain: self, asset: asset)
        }
    }

    func chainAssetIdsWithExternalBalances() -> Set<ChainAssetId> {
        let chainAssets = chainAssetsWithExternalBalances()

        return Set(chainAssets.map(\.chainAssetId))
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

    func utilityChainAsset() -> ChainAsset? {
        guard let utilityAsset = utilityAssets().first else {
            return nil
        }

        return ChainAsset(chain: self, asset: utilityAsset)
    }

    var typesUsage: TypesUsage {
        guard let types = types else {
            return .none
        }

        guard !types.overridesCommon else {
            return .onlyOwn
        }

        return types.url != nil ? .both : .onlyCommon
    }

    var defaultTip: BigUInt? {
        if let tipString = additional?.defaultTip?.stringValue {
            return BigUInt(tipString)
        } else {
            return nil
        }
    }

    var defaultBlockTimeMillis: BlockTime? {
        additional?.defaultBlockTime?.unsignedIntValue
    }

    var isUtilityTokenOnRelaychain: Bool {
        additional?.relaychainAsNative?.boolValue ?? false
    }

    var stakingMaxElectingVoters: UInt32? {
        guard let value = additional?.stakingMaxElectingVoters?.unsignedIntValue else {
            return nil
        }

        return UInt32(value)
    }

    var isDisabled: Bool {
        syncMode == .disabled
    }

    var isFullSyncMode: Bool {
        syncMode == .full
    }

    var isLightSyncMode: Bool {
        syncMode == .light
    }

    var feeViaRuntimeCall: Bool {
        additional?.feeViaRuntimeCall?.boolValue ?? false
    }
}

extension ChainModel: Identifiable {
    var identifier: String { chainId }
}

enum LocalChainOptions: String, Codable {
    case ethereumBased
    case testnet
    case crowdloans
    case governance
    case governanceV1 = "governance-v1"
    case noSubstrateRuntime
    case swapHub = "swap-hub"
    case swapHydra = "hydradx-swaps"
    case proxy
}

extension ChainModel {
    func adding(asset: AssetModel) -> ChainModel {
        .init(
            chainId: chainId,
            parentId: parentId,
            name: name,
            assets: assets.union([asset]),
            nodes: nodes,
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional,
            syncMode: syncMode
        )
    }

    func addingOrUpdating(asset: AssetModel) -> ChainModel {
        let filteredAssets = assets.filter { $0.assetId != asset.assetId }
        let newAssets = filteredAssets.union([asset])

        return .init(
            chainId: chainId,
            parentId: parentId,
            name: name,
            assets: newAssets,
            nodes: nodes,
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional,
            syncMode: syncMode
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
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional,
            syncMode: syncMode
        )
    }

    func updatingSyncMode(for newMode: ChainSyncMode) -> ChainModel {
        .init(
            chainId: chainId,
            parentId: parentId,
            name: name,
            assets: assets,
            nodes: nodes,
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional,
            syncMode: newMode
        )
    }
}

extension ChainModel {
    func getAllAssetPriceIds() -> Set<AssetModel.PriceId> {
        let priceIds = assets.compactMap(\.priceId)
        return Set(priceIds)
    }
}
