import Foundation
import BigInt

struct EvmFeeModel {
    let gasLimit: BigUInt
    let defaultGasPrice: BigUInt
    let maxPriorityGasPrice: BigUInt?

    var gasPrice: BigUInt {
        maxPriorityGasPrice ?? defaultGasPrice
    }

    var fee: BigUInt {
        gasPrice * gasLimit
    }
}
