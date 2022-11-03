import Foundation
import BigInt

struct ReferendumDelegatingLocal {
    let balance: BigUInt

    let target: AccountId

    let conviction: ConvictionVoting.Conviction

    let delegations: ConvictionVoting.Delegations

    let prior: ConvictionVoting.PriorLock

    init(remote: ConvictionVoting.Delegating) {
        balance = remote.balance
        target = remote.target
        conviction = remote.conviction
        delegations = remote.delegations
        prior = remote.prior
    }
}
