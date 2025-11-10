import Foundation

enum GiftClaimError: Error {
    case giftClaimFailed(claimingAccountId: AccountId, underlyingError: Error?)
    case alreadyClaimed
}
