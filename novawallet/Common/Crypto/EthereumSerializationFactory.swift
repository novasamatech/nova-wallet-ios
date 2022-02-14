import Foundation
import SubstrateSdk
import SwiftRLP
import BigInt

protocol EthereumSerializationFactoryProtocol {
    func serialize(
        transaction: EthereumTransaction,
        chainId: String,
        signature: EthereumSignature?
    ) throws -> Data
}

enum EthereumSerializationFactoryError: Error {
    case transactionBadField(name: String)
    case invalidChainId(value: String)
    case rlpFailed
}

final class EthereumSerializationFactory {
    private func composeSignaturePart(
        from signature: EthereumSignature?,
        chainId: BigUInt
    ) -> [AnyObject] {
        if let signature = signature {
            let dPart: BigUInt

            if signature.vPart >= 0, signature.vPart <= 3 {
                dPart = BigUInt(35)
            } else if signature.vPart >= 27, signature.vPart <= 30 {
                dPart = BigUInt(8)
            } else if signature.vPart >= 31, signature.vPart <= 34 {
                dPart = BigUInt(4)
            } else {
                dPart = BigUInt(0)
            }

            let vPart = BigUInt(signature.vPart) + dPart + chainId + chainId
            let rPart = BigUInt(signature.rPart.value)
            let sPart = BigUInt(signature.sPart.value)

            return [vPart, rPart, sPart] as [AnyObject]
        } else {
            return [
                chainId,
                BigUInt(0),
                BigUInt(0)
            ] as [AnyObject]
        }
    }
}

extension EthereumSerializationFactory: EthereumSerializationFactoryProtocol {
    func serialize(
        transaction: EthereumTransaction,
        chainId: String,
        signature: EthereumSignature?
    ) throws -> Data {
        guard let nonceHex = transaction.nonce, let nonce = BigUInt.fromHexString(nonceHex) else {
            throw EthereumSerializationFactoryError.transactionBadField(name: "nonce")
        }

        guard let gasHex = transaction.gas, let gas = BigUInt.fromHexString(gasHex) else {
            throw EthereumSerializationFactoryError.transactionBadField(name: "gas")
        }

        guard
            let gasPriceHex = transaction.gasPrice,
            let gasPrice = BigUInt.fromHexString(gasPriceHex) else {
            throw EthereumSerializationFactoryError.transactionBadField(name: "gasPrice")
        }

        guard let destination = transaction.to, let toAddress = try? Data(hexString: destination) else {
            throw EthereumSerializationFactoryError.transactionBadField(name: "to")
        }

        let value: BigUInt

        if let valueHex = transaction.value {
            guard let gotValue = BigUInt.fromHexString(valueHex) else {
                throw EthereumSerializationFactoryError.transactionBadField(name: "value")
            }

            value = gotValue
        } else {
            value = 0
        }

        let data: Data

        if let dataHex = transaction.data {
            guard let parsedData = try? Data(hexString: dataHex) else {
                throw EthereumSerializationFactoryError.transactionBadField(name: "data")
            }

            data = parsedData
        } else {
            data = Data()
        }

        var fields = [
            nonce,
            gasPrice,
            gas,
            toAddress,
            value,
            data
        ] as [AnyObject]

        guard let chainId = BigUInt.fromHexString(chainId) else {
            throw EthereumSerializationFactoryError.invalidChainId(value: chainId)
        }

        let signatureFields = composeSignaturePart(from: signature, chainId: chainId)
        fields.append(contentsOf: signatureFields)

        guard let serializedData = RLP.encode(fields) else {
            throw EthereumSerializationFactoryError.rlpFailed
        }

        return serializedData
    }
}
