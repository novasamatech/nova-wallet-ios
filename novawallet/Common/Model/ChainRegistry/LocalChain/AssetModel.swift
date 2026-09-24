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

    // local properties
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
