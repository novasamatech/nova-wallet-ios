import Foundation

struct GiftListGiftViewModel: Equatable {
    let identifier: String
    let amount: String
    let tokenImageViewModel: ImageViewModelProtocol
    let subtitle: String?
    let giftImageViewModel: ImageViewModelProtocol
    let status: Status

    static func == (lhs: GiftListGiftViewModel, rhs: GiftListGiftViewModel) -> Bool {
        lhs.identifier == rhs.identifier && lhs.status == rhs.status
    }
}

extension GiftListGiftViewModel {
    typealias Status = GiftModel.Status
}
