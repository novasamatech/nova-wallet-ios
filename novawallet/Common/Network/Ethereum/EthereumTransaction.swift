import Foundation
import BigInt

struct EthereumTransaction: Codable {
    let from: String

    // swiftlint:disable:next identifier_name
    let to: String?

    let gas: String?
    let gasPrice: String?
    let value: String?
    let data: String?
    let nonce: String?
}

extension EthereumTransaction {
    static func gasEstimationTransaction(
        from transaction: MetamaskTransaction
    ) -> EthereumTransaction {
        EthereumTransaction(
            from: transaction.from,
            to: transaction.to,
            gas: nil,
            gasPrice: nil,
            value: transaction.value,
            data: transaction.data,
            nonce: nil
        )
    }

    func replacing(gas: String?) -> EthereumTransaction {
        EthereumTransaction(
            from: from,
            to: to,
            gas: gas,
            gasPrice: gasPrice,
            value: value,
            data: data,
            nonce: nonce
        )
    }

    func replacing(gasPrice: String?) -> EthereumTransaction {
        EthereumTransaction(
            from: from,
            to: to,
            gas: gas,
            gasPrice: gasPrice,
            value: value,
            data: data,
            nonce: nonce
        )
    }

    func replacing(nonce: String?) -> EthereumTransaction {
        EthereumTransaction(
            from: from,
            to: to,
            gas: gas,
            gasPrice: gasPrice,
            value: value,
            data: data,
            nonce: nonce
        )
    }
}
