import Foundation
import BigInt

struct EthereumTransactionReceipt: Codable, Equatable {
    let blockHash: String
    let transactionHash: String
    let effectiveGasPrice: String
    let gasUsed: String
    let status: String?
    let blockNumber: String?

    var isSuccess: Bool? {
        status.map { BigUInt.fromHexString($0) == 1 }
    }

    var fee: BigUInt? {
        guard
            let gasPriceValue = BigUInt.fromHexString(effectiveGasPrice),
            let gasUsedValue = BigUInt.fromHexString(gasUsed) else {
            return nil
        }

        return gasPriceValue * gasUsedValue
    }

    var blockNumberValue: UInt64? {
        blockNumber.flatMap { BigUInt.fromHexString($0) }.flatMap { UInt64(exactly: $0) }
    }
}

extension EthereumTransactionReceipt {
    var localStatus: TransactionHistoryItem.Status {
        if let success = isSuccess {
            return success ? .success : .failed
        } else {
            return .pending
        }
    }
}
