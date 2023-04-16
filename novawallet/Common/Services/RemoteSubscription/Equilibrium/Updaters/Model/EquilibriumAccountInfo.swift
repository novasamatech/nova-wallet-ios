import BigInt
import SubstrateSdk

struct EquilibriumAccountInfo: Decodable {
    @StringCodable var nonce: UInt32
    let data: EquilibriumAccountData

    func balances<TKey>(mapKey: (EquilibriumAssetId) -> TKey?) -> [TKey: BigUInt] where TKey: Hashable {
        switch data {
        case let .v0(_, balances):
            return balances.reduce(into: [TKey: BigUInt]()) {
                if let key = mapKey($1.asset) {
                    switch $1.balance {
                    case let .positive(value):
                        $0[key] = value
                    case .negative:
                        $0[key] = BigUInt.zero
                    }
                }
            }
        }
    }

    var lock: BigUInt? {
        switch data {
        case let .v0(lock, _):
            return lock
        }
    }
}
