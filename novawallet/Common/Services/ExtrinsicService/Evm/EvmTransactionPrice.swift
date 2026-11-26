import Foundation
import BigInt

enum EvmTransactionPricing {
    case legacy(BigUInt)
    case eip1559(EvmEip1559Fees)
}

struct EvmTransactionPrice {
    let gasLimit: BigUInt
    let pricing: EvmTransactionPricing
}

struct EvmEip1559Fees {
    let maxFeePerGas: BigUInt
    let maxPriorityFeePerGas: BigUInt
}
