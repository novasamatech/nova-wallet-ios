import Foundation

struct MythosStakeModel {
    struct Amount {
        let toLock: Balance
        let toStake: Balance
    }
    
    let amount: Amount
    let collatorAccountId: AccountId
}
