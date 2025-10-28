import Foundation

enum GiftSetupViewIssue: Equatable {
    case insufficientBalance
    case minAmountViolation(String)
    case minBalanceViolation(String)
}
