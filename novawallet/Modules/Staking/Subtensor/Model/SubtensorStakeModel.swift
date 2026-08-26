import Foundation

struct SubtensorStakeModel {
    let hotkey: AccountId
    let netuid: UInt16
    let amount: Balance
    let limitPrice: Balance?

    init(
        hotkey: AccountId,
        netuid: UInt16,
        amount: Balance,
        limitPrice: Balance? = nil
    ) {
        self.hotkey = hotkey
        self.netuid = netuid
        self.amount = amount
        self.limitPrice = limitPrice
    }
}
