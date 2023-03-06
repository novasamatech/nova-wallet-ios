import Foundation
import BigInt

struct GovernanceDelegateStats: Equatable {
    let address: AccountAddress
    let delegationsCount: UInt64
    let delegatedVotes: BigUInt
    let recentVotes: UInt64
}
