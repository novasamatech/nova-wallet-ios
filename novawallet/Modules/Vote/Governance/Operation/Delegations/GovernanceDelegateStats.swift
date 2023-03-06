import Foundation
import BigInt

struct GovernanceDelegateStats: Equatable {
    let address: AccountAddress
    let delegationsCount: UInt64
    let delegatedVotes: BigUInt
    let recentVotes: UInt64

    var isEmpty: Bool {
        delegationsCount == 0 && delegatedVotes == 0 && recentVotes == 0
    }

    init(
        address: AccountAddress,
        delegationsCount: UInt64 = 0,
        delegatedVotes: BigUInt = 0,
        recentVotes: UInt64 = 0
    ) {
        self.address = address
        self.delegationsCount = delegationsCount
        self.delegatedVotes = delegatedVotes
        self.recentVotes = recentVotes
    }
}
