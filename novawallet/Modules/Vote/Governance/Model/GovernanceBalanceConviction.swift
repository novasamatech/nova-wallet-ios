import Foundation
import BigInt

struct GovernanceBalanceConviction {
    let balance: BigUInt
    let conviction: ConvictionVoting.Conviction

    var votes: BigUInt? {
        conviction.votes(for: balance)
    }
}
