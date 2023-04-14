import BigInt
import SubstrateSdk

struct EquilibriumRemoteBalance: Decodable {
    var asset: UInt32
    let balance: SignedBalance

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let asset = try container.decode(StringScaleMapper<UInt32>.self).value
        let balance = try container.decode(SignedBalance.self)
        self.asset = asset
        self.balance = balance
    }
}
