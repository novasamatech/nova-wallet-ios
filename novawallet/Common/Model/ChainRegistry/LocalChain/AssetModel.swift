import Foundation
import SubstrateSdk

struct AssetModel: Equatable, Codable, Hashable {
    enum Source: String, Codable {
        case remote
        case user
    }

    // swiftlint:disable:next type_name
    typealias Id = UInt32
    typealias PriceId = String

    static let utilityAssetId: Id = 0

    let assetId: Id
    let icon: URL?
    let name: String?
    let symbol: String
    let precision: UInt16
    let priceId: PriceId?
    let stakings: [StakingType]?
    let type: String?
    let typeExtras: JSON?
    let buyProviders: JSON?

    // local properties
    let enabled: Bool
    let source: Source

    var isUtility: Bool { assetId == Self.utilityAssetId }

    var hasStaking: Bool {
        stakings?.contains { $0 != .unsupported } ?? false
    }

    init(
        assetId: Id,
        icon: URL?,
        name: String?,
        symbol: String,
        precision: UInt16,
        priceId: PriceId?,
        stakings: [StakingType]?,
        type: String?,
        typeExtras: JSON?,
        buyProviders: JSON?,
        enabled: Bool,
        source: Source
    ) {
        self.assetId = assetId
        self.icon = icon
        self.name = name
        self.symbol = symbol
        self.precision = precision
        self.priceId = priceId
        self.stakings = stakings
        self.type = type
        self.typeExtras = typeExtras
        self.buyProviders = buyProviders
        self.enabled = enabled
        self.source = source
    }

    init(remoteModel: RemoteAssetModel, enabled: Bool) {
        assetId = remoteModel.assetId
        icon = remoteModel.icon
        name = remoteModel.name
        symbol = remoteModel.symbol
        precision = remoteModel.precision
        priceId = remoteModel.priceId
        stakings = remoteModel.staking?.map { StakingType(rawType: $0) }
        type = remoteModel.type
        typeExtras = remoteModel.typeExtras
        buyProviders = remoteModel.buyProviders
        self.enabled = enabled
        source = .remote
    }
}

extension AssetModel {
    var decimalPrecision: Int16 {
        Int16(bitPattern: precision)
    }
}

extension AssetModel {
    func byChanging(enabled: Bool) -> AssetModel {
        .init(
            assetId: assetId,
            icon: icon,
            name: name,
            symbol: symbol,
            precision: precision,
            priceId: priceId,
            stakings: stakings,
            type: type,
            typeExtras: typeExtras,
            buyProviders: buyProviders,
            enabled: enabled,
            source: source
        )
    }
}
