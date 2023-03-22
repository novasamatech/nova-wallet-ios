import Foundation
import BigInt

struct OperationContractCallModel {
    let txHash: String
    let fee: BigUInt
    let sender: DisplayAddress
    let contract: DisplayAddress
}
