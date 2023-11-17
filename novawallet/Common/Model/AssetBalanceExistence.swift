import Foundation
import BigInt

struct AssetBalanceExistence: Equatable {
    let minBalance: BigUInt
    let isSelfSufficient: Bool
}
