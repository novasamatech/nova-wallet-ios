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

    let assetId: Id
    let icon: URL?
    let name: String?
    let symbol: String
    let precision: UInt16
    let priceId: PriceId?
    let staking: String?
    let type: String?
    let typeExtras: JSON?
    let buyProviders: JSON?

    // local properties
    let enabled: Bool
    let source: Source

    var isUtility: Bool { assetId == 0 }

    init(
        assetId: Id,
        icon: URL?,
        name: String?,
        symbol: String,
        precision: UInt16,
        priceId: PriceId?,
        staking: String?,
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
        self.staking = staking
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
        staking = remoteModel.staking
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
