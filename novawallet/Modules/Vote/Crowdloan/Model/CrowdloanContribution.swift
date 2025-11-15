import Foundation

struct CrowdloanContribution {
    let paraId: ParaId
    let amount: Balance
    let unlocksAt: BlockNumber
}

extension Array where Element == CrowdloanContribution {
    func totalAmountLocked() -> Balance {
        reduce(Balance(0)) { $0 + $1.amount }
    }
}
