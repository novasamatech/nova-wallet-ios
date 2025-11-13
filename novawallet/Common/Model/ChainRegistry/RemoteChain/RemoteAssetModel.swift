import Foundation
import SubstrateSdk

struct RemoteAssetModel: Equatable, Codable, Hashable {
    // swiftlint:disable:next type_name
    typealias Id = UInt32
    typealias PriceId = String

    let assetId: Id
    let icon: String?
    let name: String?
    let symbol: String
    let precision: UInt16
    let priceId: PriceId?
    let staking: [String]?
    let type: String?
    let typeExtras: JSON?
    let buyProviders: JSON?
    let sellProviders: JSON?
    let displayPriority: UInt16?
}
