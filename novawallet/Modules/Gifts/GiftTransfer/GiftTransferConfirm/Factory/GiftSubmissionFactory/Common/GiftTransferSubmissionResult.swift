import Foundation

struct GiftTransferSubmissionResult {
    let giftId: GiftModel.Id
    let giftAccountId: AccountId,
    let sender: ExtrinsicSenderResolution?
}
