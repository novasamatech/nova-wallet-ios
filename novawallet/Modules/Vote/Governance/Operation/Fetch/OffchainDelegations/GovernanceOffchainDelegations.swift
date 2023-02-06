import Foundation

struct GovernanceOffchainDelegation: Equatable {
    let delegator: AccountAddress
    let power: GovernanceOffchainVoting.DelegatorPower
}
