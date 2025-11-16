import Foundation
import Operation_iOS
import BigInt

struct GiftModel {
    let amount: BigUInt
    let chainAssetId: ChainAssetId
    let status: Status
    let giftAccountId: AccountId
    let creationDate: Date?
    let senderMetaId: MetaAccountModel.Id?
}

extension GiftModel {
    func updating(status: Status) -> GiftModel {
        GiftModel(
            amount: amount,
            chainAssetId: chainAssetId,
            status: status,
            giftAccountId: giftAccountId,
            creationDate: creationDate,
            senderMetaId: senderMetaId
        )
    }
}

extension GiftModel: Hashable, Equatable {
    static func == (lhs: GiftModel, rhs: GiftModel) -> Bool {
        lhs.giftAccountId == rhs.giftAccountId
            && lhs.status == rhs.status
            && lhs.amount == rhs.amount
    }
}

extension GiftModel: Identifiable {
    typealias Id = String

    var identifier: Id {
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
