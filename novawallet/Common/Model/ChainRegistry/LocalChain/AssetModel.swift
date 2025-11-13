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
    typealias Symbol = String

    static let utilityAssetId: Id = 0

    let assetId: Id
    let icon: String?
    let name: String?
    let symbol: Symbol
    let precision: UInt16
    let priceId: PriceId?
    let stakings: [StakingType]?
    let type: String?
    let typeExtras: AssetTypeExtras?
    let buyProviders: JSON?
    let sellProviders: JSON?
    let displayPriority: UInt16?

    // local properties
    let enabled: Bool
    let source: Source

    var isUtility: Bool { assetId == Self.utilityAssetId }

    init(
        assetId: Id,
        icon: String?,
        name: String?,
        symbol: Symbol,
        precision: UInt16,
        priceId: PriceId?,
        stakings: [StakingType]?,
        type: String?,
        typeExtras: AssetTypeExtras?,
        buyProviders: JSON?,
        sellProviders: JSON?,
        displayPriority: UInt16?,
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
        self.sellProviders = sellProviders
        self.displayPriority = displayPriority
        self.enabled = enabled
        self.source = source
    }

    var hasPrice: Bool {
        priceId != nil
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
            sellProviders: sellProviders,
            displayPriority: displayPriority,
            enabled: enabled,
            source: source
        )
    }
    
    func byChanging(displayPriority: UInt16?) -> AssetModel {
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
            sellProviders: sellProviders,
            displayPriority: displayPriority,
            enabled: enabled,
            source: source
        )
    }
}
