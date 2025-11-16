import Foundation
import Operation_iOS
import BigInt

struct GiftModel: Hashable, Equatable {
    let amount: BigUInt
    let chainAssetId: ChainAssetId
    let status: Status
    let giftAccountId: AccountId
    let senderMetaId: MetaAccountModel.Id?

    static func == (lhs: GiftModel, rhs: GiftModel) -> Bool {
        lhs.giftAccountId == rhs.giftAccountId
            && lhs.status == rhs.status
            && lhs.amount == rhs.amount
    }
}

extension GiftModel {
    typealias Id = AccountId
}

extension GiftModel: Identifiable {
    var identifier: String {
        giftAccountId.toHex()
    }
}

extension GiftModel {
    enum Status: Int16 {
        case pending
        case claimed
        case reclaimed
    }
}
