import Foundation
import BigInt

struct ReferendumDelegatingLocal {
    let balance: BigUInt

    let target: AccountId

    let conviction: ConvictionVoting.Conviction

    init(remote: ConvictionVoting.Delegating) {
        balance = remote.balance
        target = remote.target
        conviction = remote.conviction
    }

    init(balance: BigUInt, target: AccountId, conviction: ConvictionVoting.Conviction) {
        self.balance = balance
        self.target = target
        self.conviction = conviction
    }
}
