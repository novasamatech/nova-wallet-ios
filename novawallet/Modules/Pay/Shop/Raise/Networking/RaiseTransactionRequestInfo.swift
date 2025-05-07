import Foundation
import BigInt

struct RaiseTransactionRequestInfo {
    let orderId: String
    let brandId: String
    let paymentToken: ChainAssetId
    let amount: BigUInt
}

struct RaiseTransactionUpdateInfo {
    let transactionId: String
    let brandId: String
    let paymentToken: ChainAssetId
    let amount: BigUInt
}
