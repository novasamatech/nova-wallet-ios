import Foundation
import Operation_iOS
import BigInt

struct GiftModel {
    let amount: BigUInt
    let chainAssetId: ChainAssetId
    let status: Status
    let giftAccountId: AccountId
    let metaId: MetaAccountModel.Id
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
