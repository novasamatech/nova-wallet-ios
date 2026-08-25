import Foundation

struct SubtensorUnstakeModel {
    let hotkey: AccountId
    let netuid: UInt16
    let amount: Balance
    let isFullUnstake: Bool
}
