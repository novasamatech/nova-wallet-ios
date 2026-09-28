import Foundation

struct SubtensorUnstakeModel {
    let hotkey: AccountId
    let netuid: UInt16
    let amount: Balance
    let exitHotkeys: [AccountId]?

    var isFullUnstake: Bool {
        exitHotkeys != nil
    }
}
