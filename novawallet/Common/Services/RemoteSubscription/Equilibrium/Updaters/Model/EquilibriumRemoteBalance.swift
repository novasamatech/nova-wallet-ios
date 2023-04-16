import BigInt
import SubstrateSdk

struct EquilibriumRemoteBalance: Decodable {
    var asset: EquilibriumAssetId
    let balance: SignedBalance

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let asset = try container.decode(StringScaleMapper<EquilibriumAssetId>.self).value
        let balance = try container.decode(SignedBalance.self)
        self.asset = asset
        self.balance = balance
    }
}
