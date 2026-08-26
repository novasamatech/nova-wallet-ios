import Foundation

struct SubtensorUnstakeModel {
    let hotkey: AccountId
    let netuid: UInt16
    let amount: Balance
    let isFullUnstake: Bool
    let limitPrice: Balance?

    init(
        hotkey: AccountId,
        netuid: UInt16,
        amount: Balance,
        isFullUnstake: Bool,
        limitPrice: Balance? = nil
    ) {
        self.hotkey = hotkey
        self.netuid = netuid
        self.amount = amount
        self.isFullUnstake = isFullUnstake
        self.limitPrice = limitPrice
    }
}
