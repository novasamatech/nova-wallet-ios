import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

struct ChainModel: Equatable, Hashable {
    // swiftlint:disable:next type_name
    typealias Id = String

    typealias AddressPrefix = UInt64

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

    enum Source: String, Codable {
        case remote
        case user
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

    enum ConnectionMode: Hashable, Equatable {
        case manual(ChainNodeModel)
        case autoBalanced

        var rawValue: Int16 {
            switch self {
            case .manual: 0
            case .autoBalanced: 1
            }
        }

        init?(rawValue: Int16, selectedNode: ChainNodeModel?) {
            switch (rawValue, selectedNode) {
            case let (0, .some(node)):
                self = .manual(node)
            case (1, _):
                self = .autoBalanced
            default:
                return nil
            }
        }
    }

    let chainId: Id
    let parentId: Id?
    let name: String
    let assets: Set<AssetModel>
    let nodes: Set<ChainNodeModel>
    let addressPrefix: AddressPrefix
    let legacyAddressPrefix: AddressPrefix?
    let types: TypesSettings?
    let icon: URL?
    let options: [LocalChainOptions]?
    let externalApis: LocalChainExternalApiSet?
    let nodeSwitchStrategy: NodeSwitchStrategy
    let explorers: [Explorer]?
    let order: Int64
    let additional: JSON?
    let syncMode: ChainSyncMode
    let source: Source
    let connectionMode: ConnectionMode

    init(
        chainId: Id,
        parentId: Id?,
        name: String,
        assets: Set<AssetModel>,
        nodes: Set<ChainNodeModel>,
        nodeSwitchStrategy: NodeSwitchStrategy,
        addressPrefix: AddressPrefix,
        legacyAddressPrefix: AddressPrefix?,
        types: TypesSettings?,
        icon: URL?,
        options: [LocalChainOptions]?,
        externalApis: LocalChainExternalApiSet?,
        explorers: [Explorer]?,
        order: Int64,
        additional: JSON?,
        syncMode: ChainSyncMode,
        source: Source,
        connectionMode: ConnectionMode
    ) {
        self.chainId = chainId
        self.parentId = parentId
        self.name = name
        self.assets = assets
        self.nodes = nodes
        self.nodeSwitchStrategy = nodeSwitchStrategy
        self.addressPrefix = addressPrefix
        self.legacyAddressPrefix = legacyAddressPrefix
        self.types = types
        self.icon = icon
        self.options = options
        self.externalApis = externalApis
        self.explorers = explorers
        self.order = order
        self.additional = additional
        self.syncMode = syncMode
        self.source = source
        self.connectionMode = connectionMode
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

    var hasUnifiedAddressPrefix: Bool {
        legacyAddressPrefix != nil
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

    var hasAssetHubFees: Bool {
        options?.contains(where: { $0 == .assetHubFees }) ?? false
    }

    var hasHydrationFees: Bool {
        options?.contains(where: { $0 == .hydrationFees }) ?? false
    }

    var hasCustomFees: Bool {
        hasAssetHubFees || hasHydrationFees
    }

    var hasProxy: Bool {
        options?.contains(where: { $0 == .proxy }) ?? false
    }
    
    var hasMultisig: Bool {
        options?.contains(where: { $0 == .multisig }) ?? false
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

    var hasPushNotifications: Bool {
        options?.contains(where: { $0 == .pushNotifications }) ?? false
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

    func chainAssets() -> [ChainAsset] {
        assets.map { ChainAsset(chain: self, asset: $0) }
    }

    func chainAsset(for assetId: AssetModel.Id) -> ChainAsset? {
        guard let asset = assets.first(where: { $0.assetId == assetId }) else {
            return nil
        }

        return .init(chain: self, asset: asset)
    }

    func chainAssetOrError(for assetId: AssetModel.Id) throws -> ChainAsset {
        guard let chainAsset = chainAsset(for: assetId) else {
            throw ChainModelFetchError.noAsset(assetId: assetId)
        }

        return chainAsset
    }

    func chainAssetForSymbol(_ symbol: String) -> ChainAsset? {
        guard let asset = assets.first(where: { $0.symbol == symbol }) else {
            return nil
        }

        return .init(chain: self, asset: asset)
    }

    func chainAssetForSymbolOrError(_ symbol: String) throws -> ChainAsset {
        guard let asset = chainAssetForSymbol(symbol) else {
            throw ChainModelFetchError.noAssetForSymbol(symbol)
        }

        return asset
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

    var identityChain: ChainModel.Id? {
        additional?.identityChain?.stringValue
    }

    var supportsGenericLedgerApp: Bool {
        additional?.supportsGenericLedgerApp?.boolValue ?? false
    }

    var disabledCheckMetadataHash: Bool {
        additional?.disabledCheckMetadataHash?.boolValue ?? false
    }

    var isAddedByUser: Bool {
        source == .user
    }
}

extension ChainModel: Identifiable {
    var identifier: String { chainId }
}

enum LocalChainOptions: String, Codable, Equatable {
    case ethereumBased
    case testnet
    case crowdloans
    case governance
    case governanceV1 = "governance-v1"
    case noSubstrateRuntime
    case swapHub = "swap-hub"
    case swapHydra = "hydradx-swaps"
    case proxy
    case multisig
    case pushNotifications = "pushSupport"
    case assetHubFees = "assethub-fees"
    case hydrationFees = "hydration-fees"
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
            legacyAddressPrefix: legacyAddressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional,
            syncMode: syncMode,
            source: source,
            connectionMode: connectionMode
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
            legacyAddressPrefix: legacyAddressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional,
            syncMode: syncMode,
            source: source,
            connectionMode: connectionMode
        )
    }

    func adding(node: ChainNodeModel) -> ChainModel {
        var mutNodes = nodes

        mutNodes.insert(node)

        return .init(
            chainId: chainId,
            parentId: parentId,
            name: name,
            assets: assets,
            nodes: mutNodes,
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix,
            legacyAddressPrefix: legacyAddressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional,
            syncMode: syncMode,
            source: source,
            connectionMode: connectionMode
        )
    }

    func adding(nodes: Set<ChainNodeModel>) -> ChainModel {
        .init(
            chainId: chainId,
            parentId: parentId,
            name: name,
            assets: assets,
            nodes: self.nodes.union(nodes),
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix,
            legacyAddressPrefix: legacyAddressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional,
            syncMode: syncMode,
            source: source,
            connectionMode: connectionMode
        )
    }

    func removing(node: ChainNodeModel) -> ChainModel {
        var mutNodes = nodes

        mutNodes.remove(node)

        return .init(
            chainId: chainId,
            parentId: parentId,
            name: name,
            assets: assets,
            nodes: mutNodes,
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix,
            legacyAddressPrefix: legacyAddressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional,
            syncMode: syncMode,
            source: source,
            connectionMode: connectionMode
        )
    }

    func replacing(
        _ oldNode: ChainNodeModel,
        with newNode: ChainNodeModel
    ) -> ChainModel {
        var mutNodes = nodes

        mutNodes.remove(oldNode)
        mutNodes.insert(newNode)

        return .init(
            chainId: chainId,
            parentId: parentId,
            name: name,
            assets: assets,
            nodes: mutNodes,
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix,
            legacyAddressPrefix: legacyAddressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional,
            syncMode: syncMode,
            source: source,
            connectionMode: connectionMode
        )
    }

    func byChanging(
        assets: Set<AssetModel>? = nil,
        name: String? = nil,
        source: Source? = nil
    ) -> ChainModel {
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
            legacyAddressPrefix: legacyAddressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional,
            syncMode: syncMode,
            source: source ?? self.source,
            connectionMode: connectionMode
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
            legacyAddressPrefix: legacyAddressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional,
            syncMode: newMode,
            source: source,
            connectionMode: connectionMode
        )
    }

    func updatingConnectionMode(for newMode: ConnectionMode) -> ChainModel {
        .init(
            chainId: chainId,
            parentId: parentId,
            name: name,
            assets: assets,
            nodes: nodes,
            nodeSwitchStrategy: nodeSwitchStrategy,
            addressPrefix: addressPrefix,
            legacyAddressPrefix: legacyAddressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApis: externalApis,
            explorers: explorers,
            order: order,
            additional: additional,
            syncMode: syncMode,
            source: source,
            connectionMode: newMode
        )
    }
}

extension ChainModel {
    func getAllAssetPriceIds() -> Set<AssetModel.PriceId> {
        let priceIds = assets.compactMap(\.priceId)
        return Set(priceIds)
    }

    var genesisHash: Data? {
        guard !isPureEvm else {
            return nil
        }

        return try? Data(hexString: chainId)
    }
}

extension ChainModel.AddressPrefix {
    func toSubstrateFormat() -> UInt16 {
        // The assumption is that we don't map values overflowing UInt16
        // in the ChainModel for substrate networks.
        UInt16(self)
    }
}

// MARK: ChainNodeConnectable

protocol ChainNodeConnectable {
    var chainId: String { get }
    var name: String { get }
    var nodes: Set<ChainNodeModel> { get }
    var options: [LocalChainOptions]? { get }
    var nodeSwitchStrategy: ChainModel.NodeSwitchStrategy { get }
    var addressPrefix: ChainModel.AddressPrefix { get }
    var connectionMode: ChainModel.ConnectionMode { get }
}

extension ChainNodeConnectable {
    var noSubstrateRuntime: Bool {
        options?.contains(where: { $0 == .noSubstrateRuntime }) ?? false
    }

    var hasSubstrateRuntime: Bool {
        !noSubstrateRuntime
    }

    var isEthereumBased: Bool {
        options?.contains(.ethereumBased) ?? false
    }

    var isPureEvm: Bool {
        isEthereumBased && !hasSubstrateRuntime
    }
}

// MARK: ChainViewModelSource

protocol ChainViewModelSource {
    var icon: URL? { get }
    var name: String { get }
}

extension ChainModel: ChainNodeConnectable {}
extension ChainModel: ChainViewModelSource {}
