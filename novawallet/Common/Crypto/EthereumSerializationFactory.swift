import Foundation
import SubstrateSdk
import SwiftRLP
import BigInt

protocol EthereumSerializationFactoryProtocol {
    func serialize(
        transaction: EthereumTransaction,
        chainId: String,
        signature: EthereumSignature?,
        eip1559Fees: EvmEip1559Fees?
    ) throws -> Data

    func serializeSignatureWithReplayProtection(
        for signature: EthereumSignature,
        chainId: String
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
        signature: EthereumSignature?,
        eip1559Fees: EvmEip1559Fees?
    ) throws -> Data {
        if let eip1559Fees {
            return try serializeEip1559(
                transaction: transaction,
                fees: eip1559Fees,
                chainId: chainId,
                signature: signature
            )
        } else {
            return try serializeLegacy(transaction: transaction, chainId: chainId, signature: signature)
        }
    }

    private func serializeLegacy(
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

    func serializeSignatureWithReplayProtection(
        for signature: EthereumSignature,
        chainId: String
    ) throws -> Data {
        guard let chainId = BigUInt.fromHexString(chainId) else {
            throw EthereumSerializationFactoryError.invalidChainId(value: chainId)
        }

        let signatureFields = composeSignaturePart(from: signature, chainId: chainId)

        guard let serializedData = RLP.encode(signatureFields) else {
            throw EthereumSerializationFactoryError.rlpFailed
        }

        return serializedData
    }
}

// MARK: - Private

private extension EthereumSerializationFactory {
    enum Constants {
        static let eip1559TransactionType: UInt8 = 0x02
    }

    func serializeEip1559(
        transaction: EthereumTransaction,
        fees: EvmEip1559Fees,
        chainId: String,
        signature: EthereumSignature?
    ) throws -> Data {
        guard fees.maxPriorityFeePerGas <= fees.maxFeePerGas else {
            throw EthereumSerializationFactoryError.transactionBadField(name: "maxPriorityFeePerGas")
        }

        guard let chainIdValue = BigUInt.fromHexString(chainId) else {
            throw EthereumSerializationFactoryError.invalidChainId(value: chainId)
        }

        guard let nonceHex = transaction.nonce, let nonce = BigUInt.fromHexString(nonceHex) else {
            throw EthereumSerializationFactoryError.transactionBadField(name: "nonce")
        }

        guard let gasHex = transaction.gas, let gas = BigUInt.fromHexString(gasHex) else {
            throw EthereumSerializationFactoryError.transactionBadField(name: "gas")
        }

        guard let destination = transaction.to, let toAddress = try? Data(hexString: destination) else {
            throw EthereumSerializationFactoryError.transactionBadField(name: "to")
        }

        let value = try transaction.value.map { valueHex -> BigUInt in
            guard let value = BigUInt.fromHexString(valueHex) else {
                throw EthereumSerializationFactoryError.transactionBadField(name: "value")
            }

            return value
        } ?? 0

        let data = try transaction.data.map { dataHex -> Data in
            guard let data = try? Data(hexString: dataHex) else {
                throw EthereumSerializationFactoryError.transactionBadField(name: "data")
            }

            return data
        } ?? Data()

        var fields = [
            chainIdValue,
            nonce,
            fees.maxPriorityFeePerGas,
            fees.maxFeePerGas,
            gas,
            toAddress,
            value,
            data,
            [] as [AnyObject]
        ] as [AnyObject]

        if let signature {
            fields.append(contentsOf: try composeEip1559SignaturePart(from: signature))
        }

        guard let serializedData = RLP.encode(fields) else {
            throw EthereumSerializationFactoryError.rlpFailed
        }

        return Data([Constants.eip1559TransactionType]) + serializedData
    }

    func composeEip1559SignaturePart(from signature: EthereumSignature) throws -> [AnyObject] {
        let yParity: UInt8

        switch signature.vPart {
        case 0, 1:
            yParity = signature.vPart
        case 27, 28:
            yParity = signature.vPart - 27
        default:
            throw EthereumSerializationFactoryError.transactionBadField(name: "v")
        }

        return [
            BigUInt(yParity),
            BigUInt(signature.rPart.value),
            BigUInt(signature.sPart.value)
        ] as [AnyObject]
    }
}
