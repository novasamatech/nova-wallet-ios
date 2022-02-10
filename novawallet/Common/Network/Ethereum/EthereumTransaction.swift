import Foundation

struct EthereumTransaction: Codable {
    let from: String
    let to: String?
    let gas: String?
    let gasPrice: String?
    let value: String?
    let data: String
}

extension EthereumTransaction {
    static func gasEstimationTransaction(from tx: MetamaskTransaction) -> EthereumTransaction {
        EthereumTransaction(
            from: tx.from,
            to: tx.to,
            gas: nil,
            gasPrice: nil,
            value: tx.value,
            data: tx.data
        )
    }
}
