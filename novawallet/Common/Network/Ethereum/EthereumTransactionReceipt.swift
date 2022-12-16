import Foundation
import BigInt

struct EthereumTransactionReceipt: Codable {
    let blockHash: String
    let transactionHash: String
    let effectiveGasPrice: String
    let gasUsed: String

    var fee: BigUInt? {
        guard
            let gasPriceValue = BigUInt.fromHexString(effectiveGasPrice),
            let gasUsedValue = BigUInt.fromHexString(gasUsed) else {
            return nil
        }

        return gasPriceValue * gasUsedValue
    }
}
