import Foundation
import BigInt
import SubstrateSdk

protocol EvmTransactionBuilding: AnyObject {
    func toAddress(_ address: AccountAddress) -> EvmTransactionBuilding
    func usingGasPrice(_ gasPrice: BigUInt) -> EvmTransactionBuilding
    func usingGasLimit(_ gasLimit: BigUInt) -> EvmTransactionBuilding
    func usingNonce(_ nonce: UInt) -> EvmTransactionBuilding
    func sendingValue(_ value: BigUInt) -> EvmTransactionBuilding
    func usingTransactionData(_ data: Data) -> EvmTransactionBuilding
    func buildTransaction() -> EthereumTransaction
    func signing(using closure: (Data) throws -> Data) throws -> EvmTransactionBuilding
    func build() throws -> Data
}

enum EvmTransactionBuilderError: Error {
    case invalidDataParameters
    case invalidSignature(String)
}

final class EvmTransactionBuilder: EvmTransactionBuilding {
    let chainId: String

    private var transaction: EthereumTransaction
    private var signature: EthereumSignature?

    private var serializer = EthereumSerializationFactory()

    init(address: AccountAddress, chainId: String) {
        transaction = .init(from: address, to: nil, gas: nil, gasPrice: nil, value: nil, data: nil, nonce: nil)
        self.chainId = chainId
    }

    func toAddress(_ address: AccountAddress) -> EvmTransactionBuilding {
        transaction = transaction.replacing(recepient: address)
        return self
    }

    func usingGasPrice(_ gasPrice: BigUInt) -> EvmTransactionBuilding {
        transaction = transaction.replacing(gasPrice: String(gasPrice))
        return self
    }

    func usingGasLimit(_ gasLimit: BigUInt) -> EvmTransactionBuilding {
        transaction = transaction.replacing(gas: String(gasLimit))
        return self
    }

    func usingNonce(_ nonce: UInt) -> EvmTransactionBuilding {
        transaction = transaction.replacing(nonce: String(nonce))
        return self
    }

    func sendingValue(_ value: BigUInt) -> EvmTransactionBuilding {
        transaction = transaction.replacing(value: String(value))
        return self
    }

    func usingTransactionData(_ data: Data) -> EvmTransactionBuilding {
        transaction = transaction.replacing(data: data)
        return self
    }

    func buildTransaction() -> EthereumTransaction {
        transaction
    }

    func signing(using closure: (Data) throws -> Data) throws -> EvmTransactionBuilding {
        let signingData = try serializer.serialize(
            transaction: transaction,
            chainId: chainId,
            signature: nil
        )

        let rawSignature = try closure(signingData)

        guard let signature = EthereumSignature(rawValue: rawSignature) else {
            throw EvmTransactionBuilderError.invalidSignature(rawSignature.toHex(includePrefix: true))
        }

        self.signature = signature

        return self
    }

    func build() throws -> Data {
        try serializer.serialize(
            transaction: transaction,
            chainId: chainId,
            signature: signature
        )
    }
}
