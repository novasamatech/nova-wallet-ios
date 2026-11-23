import Foundation
import BigInt

struct EvmTransactionPrice {
    let gasLimit: BigUInt
    let gasPrice: BigUInt
}

struct EvmEip1559Fees {
    let maxFeePerGas: BigUInt
    let maxPriorityFeePerGas: BigUInt
}
