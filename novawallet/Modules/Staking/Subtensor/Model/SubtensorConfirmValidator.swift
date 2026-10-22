import Foundation

struct SubtensorConfirmValidator {
    let hotkey: AccountId
    let display: DisplayAddress
    let annualRate: Decimal?

    var name: String {
        display.username.isEmpty ? display.address.truncated : display.username
    }
}
