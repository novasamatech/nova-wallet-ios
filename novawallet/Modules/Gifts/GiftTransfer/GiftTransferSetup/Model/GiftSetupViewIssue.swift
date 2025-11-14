import Foundation

enum GiftSetupViewIssue: Equatable {
    case insufficientBalance(IssueAttributes)
    case minAmountViolation(IssueAttributes)

    var actionText: String {
        switch self {
        case let .insufficientBalance(attributes), let .minAmountViolation(attributes):
            attributes.actionText
        }
    }
}

extension GiftSetupViewIssue {
    struct IssueAttributes: Equatable {
        let issueText: String
        let actionText: String
        let getTokensButtonVisible: Bool
    }
}
