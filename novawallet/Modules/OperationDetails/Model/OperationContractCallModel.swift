import Foundation
import BigInt

struct OperationContractCallModel {
    let txHash: String
    let fee: BigUInt
    let feePriceData: PriceData?
    let sender: DisplayAddress
    let contract: DisplayAddress
    let functionName: String?
}
