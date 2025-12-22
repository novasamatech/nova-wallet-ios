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
    enum Status {
        case pending
        case syncing
        case claimed
        case reclaimed

        init?(
            from status: GiftModel.Status,
            isSyncing: Bool
        ) {
            guard !isSyncing else {
                self = .syncing
                return
            }

            switch status {
            case .pending:
                self = .pending
            case .claimed:
                self = .claimed
            case .reclaimed:
                self = .reclaimed
            case .created:
                return nil
            }
        }
    }
}
