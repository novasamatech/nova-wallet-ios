import Foundation
import BigInt

struct OperationTransferModel {
    let txHash: String
    let amount: BigUInt
    let amountPriceData: PriceData?
    let fee: BigUInt
    let feePriceData: PriceData?
    let sender: DisplayAddress
    let receiver: DisplayAddress
    let outgoing: Bool
}
