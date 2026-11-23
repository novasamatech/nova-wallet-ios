import Foundation
import BigInt

struct EvmFeeModel {
    let gasLimit: BigUInt
    let defaultGasPrice: BigUInt
    let eip1559: EvmEip1559Fee?

    var maxPriorityGasPrice: BigUInt? {
        eip1559?.expectedGasPrice
    }

    var gasPrice: BigUInt {
        maxPriorityGasPrice ?? defaultGasPrice
    }

    var fee: BigUInt {
        gasPrice * gasLimit
    }

    var reserve: BigUInt {
        (eip1559?.fees.maxFeePerGas ?? defaultGasPrice) * gasLimit
    }

    var transactionPrice: EvmTransactionPrice {
        let pricing: EvmTransactionPricing = eip1559.map { .eip1559($0.fees) } ?? .legacy(defaultGasPrice)

        return EvmTransactionPrice(gasLimit: gasLimit, pricing: pricing)
    }

    func forcingLegacy() -> EvmFeeModel {
        EvmFeeModel(gasLimit: gasLimit, defaultGasPrice: gasPrice, eip1559: nil)
    }
}

struct EvmEip1559Fee {
    enum Constants {
        static let baseFeeMultiplier: BigUInt = 2
        static let minPriorityFeePerGas: BigUInt = 1_000_000
    }

    let baseFee: BigUInt
    let fees: EvmEip1559Fees

    var expectedGasPrice: BigUInt {
        min(baseFee + fees.maxPriorityFeePerGas, fees.maxFeePerGas)
    }

    static func nova(baseFee: BigUInt, nodeTip: BigUInt) -> EvmEip1559Fee {
        let tip = max(nodeTip, Constants.minPriorityFeePerGas)

        return EvmEip1559Fee(
            baseFee: baseFee,
            fees: EvmEip1559Fees(
                maxFeePerGas: Constants.baseFeeMultiplier * baseFee + tip,
                maxPriorityFeePerGas: tip
            )
        )
    }
}
