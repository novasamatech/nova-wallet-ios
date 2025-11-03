import Foundation

enum GiftTransferConfirmError: Error {
    case giftSubmissionFailed(giftAccountId: AccountId, underlyingError: Error?)
}
