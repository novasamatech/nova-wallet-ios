import SubstrateSdk

struct EquilibriumTokenTransfer: Codable {
    @StringCodable var assetId: UInt64
    @BytesCodable var destinationAccountId: AccountId
    let balance: SignedBalance

    enum CodingKeys: String, CodingKey {
        case assetId
        case destinationAccountId = "to"
        case balance = "value"
    }
}
