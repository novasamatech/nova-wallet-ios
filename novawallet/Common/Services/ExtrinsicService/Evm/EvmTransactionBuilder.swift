import Foundation
import BigInt
import SubstrateSdk

protocol EvmTransactionBuilderProtocol: AnyObject {
    func toAddress(_ address: AccountAddress) -> EvmTransactionBuilderProtocol
    func usingGasPrice(_ gasPrice: BigUInt) -> EvmTransactionBuilderProtocol
    func usingGasLimit(_ gasLimit: BigUInt) -> EvmTransactionBuilderProtocol
    func usingNonce(_ nonce: BigUInt) -> EvmTransactionBuilderProtocol
    func sendingValue(_ value: BigUInt) -> EvmTransactionBuilderProtocol
    func usingTransactionData(_ data: Data) -> EvmTransactionBuilderProtocol
    func buildTransaction() -> EthereumTransaction
    func signing(using closure: (Data) throws -> Data) throws -> EvmTransactionBuilderProtocol
    func build() throws -> Data
}

enum EvmTransactionBuilderError: Error {
    case invalidDataParameters
    case invalidSignature(String)
}

final class EvmTransactionBuilder: EvmTransactionBuilderProtocol {
    let chainId: String

    private var transaction: EthereumTransaction
    private var signature: EthereumSignature?

    private var serializer = EthereumSerializationFactory()

    init(address: AccountAddress, chainId: String) {
        transaction = .init(from: address, to: nil, gas: nil, gasPrice: nil, value: nil, data: nil, nonce: nil)
        self.chainId = chainId
    }

    func toAddress(_ address: AccountAddress) -> EvmTransactionBuilderProtocol {
        transaction = transaction.replacing(recepient: address)
        return self
    }

    func usingGasPrice(_ gasPrice: BigUInt) -> EvmTransactionBuilderProtocol {
        transaction = transaction.replacing(gasPrice: gasPrice.toHexString())
        return self
    }

    func usingGasLimit(_ gasLimit: BigUInt) -> EvmTransactionBuilderProtocol {
        transaction = transaction.replacing(gas: gasLimit.toHexString())
        return self
    }

    func usingNonce(_ nonce: BigUInt) -> EvmTransactionBuilderProtocol {
        transaction = transaction.replacing(nonce: nonce.toHexString())
        return self
    }

    func sendingValue(_ value: BigUInt) -> EvmTransactionBuilderProtocol {
        transaction = transaction.replacing(value: value.toHexString())
        return self
    }

    func usingTransactionData(_ data: Data) -> EvmTransactionBuilderProtocol {
        transaction = transaction.replacing(data: data)
        return self
    }

    func buildTransaction() -> EthereumTransaction {
        transaction
    }

    func signing(using closure: (Data) throws -> Data) throws -> EvmTransactionBuilderProtocol {
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
