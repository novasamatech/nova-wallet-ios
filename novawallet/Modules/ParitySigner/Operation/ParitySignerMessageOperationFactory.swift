import Foundation
import Operation_iOS

enum ParitySignerNetworkType: UInt8 {
    case substrate = 83 // 0x53

    var bytes: Data {
        Data([rawValue])
    }
}

enum ParitySignerMessageType: UInt8 {
    case transaction = 2
    case message = 3
    case ddTransactionWithProof = 5
    case transactionWithProof = 6

    var bytes: Data {
        Data([rawValue])
    }
}

enum ParitySignerCryptoType: UInt8 {
    case ed25519 = 0
    case sr25519 = 1
    case ecdsa = 2
    case ethereum = 3

    init?(cryptoType: MultiassetCryptoType) {
        switch cryptoType {
        case .sr25519:
            self = .sr25519
        case .ed25519:
            self = .ed25519
        case .substrateEcdsa:
            self = .ecdsa
        case .ethereumEcdsa:
            self = .ethereum
        }
    }

    var bytes: Data {
        Data([rawValue])
    }
}

protocol ParitySignerMessageOperationFactoryProtocol {
    func createMetadataBasedTransaction(
        for extrinsicPayload: Data,
        accountId: AccountId,
        cryptoType: MultiassetCryptoType,
        genesisHash: String
    ) -> CompoundOperationWrapper<Data>

    func createProofBasedTransaction(
        for extrinsicPayload: Data,
        metadataProofClosure: @escaping () throws -> Data,
        accountId: AccountId,
        cryptoType: MultiassetCryptoType,
        genesisHash: String
    ) -> CompoundOperationWrapper<Data>

    func createMessage(
        for payload: Data,
        accountId: AccountId,
        cryptoType: MultiassetCryptoType,
        genesisHash: String
    ) -> CompoundOperationWrapper<Data>
}

final class ParitySignerMessageOperationFactory {
    let networkType: ParitySignerNetworkType

    init(networkType: ParitySignerNetworkType = .substrate) {
        self.networkType = networkType
    }
}

enum ParitySignerMessageOperationFactoryError: Error {
    case unsupportedCryptoType
}

extension ParitySignerMessageOperationFactory: ParitySignerMessageOperationFactoryProtocol {
    func createMetadataBasedTransaction(
        for extrinsicPayload: Data,
        accountId: AccountId,
        cryptoType: MultiassetCryptoType,
        genesisHash: String
    ) -> CompoundOperationWrapper<Data> {
        let networkCodeBytes = networkType.bytes

        let operation = ClosureOperation<Data> {
            guard let cryptoTypeBytes = ParitySignerCryptoType(cryptoType: cryptoType)?.bytes else {
                throw ParitySignerMessageOperationFactoryError.unsupportedCryptoType
            }

            let messageTypeBytes = ParitySignerMessageType.transaction.bytes

            let genesisHashData = try Data(hexString: genesisHash)

            let prefix: Data = networkCodeBytes + cryptoTypeBytes + messageTypeBytes + accountId

            return prefix + extrinsicPayload + genesisHashData
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createProofBasedTransaction(
        for extrinsicPayload: Data,
        metadataProofClosure: @escaping () throws -> Data,
        accountId: AccountId,
        cryptoType: MultiassetCryptoType,
        genesisHash: String
    ) -> CompoundOperationWrapper<Data> {
        let networkCodeBytes = networkType.bytes

        let operation = ClosureOperation<Data> {
            guard let cryptoTypeBytes = ParitySignerCryptoType(cryptoType: cryptoType)?.bytes else {
                throw ParitySignerMessageOperationFactoryError.unsupportedCryptoType
            }

            let messageTypeBytes = ParitySignerMessageType.ddTransactionWithProof.bytes

            let genesisHashData = try Data(hexString: genesisHash)

            let derivationPath = try "".scaleEncoded()
            let prefix: Data = networkCodeBytes + cryptoTypeBytes + messageTypeBytes + accountId + derivationPath

            let metadataProof = try metadataProofClosure()

            return prefix + metadataProof + extrinsicPayload + genesisHashData
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createMessage(
        for payload: Data,
        accountId: AccountId,
        cryptoType: MultiassetCryptoType,
        genesisHash: String
    ) -> CompoundOperationWrapper<Data> {
        let networkCodeBytes = networkType.bytes

        let operation = ClosureOperation<Data> {
            guard let cryptoTypeBytes = ParitySignerCryptoType(cryptoType: cryptoType)?.bytes else {
                throw ParitySignerMessageOperationFactoryError.unsupportedCryptoType
            }

            let messageTypeBytes = ParitySignerMessageType.message.bytes

            let genesisHashData = try Data(hexString: genesisHash)

            let prefix: Data = networkCodeBytes + cryptoTypeBytes + messageTypeBytes + accountId

            return prefix + payload + genesisHashData
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
