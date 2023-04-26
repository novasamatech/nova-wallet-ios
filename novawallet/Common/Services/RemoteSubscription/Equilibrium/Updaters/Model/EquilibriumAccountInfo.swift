import BigInt
import SubstrateSdk

struct EquilibriumAccountInfo: Decodable {
    @StringCodable var nonce: UInt32
    let data: EquilibriumAccountData

    var balances: [EquilibriumRemoteBalance] {
        switch data {
        case let .v0(_, balance):
            return balance
        }
    }

    var lock: BigUInt? {
        switch data {
        case let .v0(lock, _):
            return lock
        }
    }
}
