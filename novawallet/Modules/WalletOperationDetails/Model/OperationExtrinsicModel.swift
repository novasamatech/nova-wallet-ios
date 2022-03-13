import Foundation
import BigInt

struct OperationExtrinsicModel {
    let txHash: String
    let call: String
    let module: String
    let sender: DisplayAddress
    let fee: BigUInt
}
