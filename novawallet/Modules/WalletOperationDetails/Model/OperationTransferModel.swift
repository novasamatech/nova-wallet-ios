import Foundation
import BigInt

struct OperationTransferModel {
    let txHash: String
    let amount: BigUInt
    let fee: BigUInt
    let sender: DisplayAddress
    let receiver: DisplayAddress
    let outgoing: Bool
}
