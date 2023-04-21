import SubstrateSdk
import BigInt

struct EquilibriumTokenTransfer: Codable {
    @StringCodable var assetId: EquilibriumAssetId
    var destinationAccountId: AccountId
    @StringCodable var value: BigUInt

    enum CodingKeys: String, CodingKey {
        case assetId = "asset"
        case destinationAccountId = "to"
        case value
    }
}
