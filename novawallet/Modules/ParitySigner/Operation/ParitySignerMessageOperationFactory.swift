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
    case concreteChainMessage = 3
    case ddTransaction = 5
    case transactionWithProof = 6
    case ddTransactionWithProof = 7
    case anyChainMessage = 8
    case ddExportKeyset = 222 // 0xde

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
        signingIdentity: ParitySignerSigningIdentity,
        genesisHash: String
    ) -> CompoundOperationWrapper<Data>

    func createProofBasedTransaction(
        for extrinsicPayload: Data,
        metadataProofClosure: @escaping () throws -> Data,
        signingIdentity: ParitySignerSigningIdentity,
        genesisHash: String
    ) -> CompoundOperationWrapper<Data>

    func createMessage(
        for payload: Data,
        accountId: AccountId,
        cryptoType: MultiassetCryptoType,
        genesisHash: String?
    ) -> CompoundOperationWrapper<Data>
}

enum ParitySignerMessageOperationFactoryError: Error {
    case unsupportedCryptoType
}

final class ParitySignerMessageOperationFactory {
    let networkType: ParitySignerNetworkType

    init(networkType: ParitySignerNetworkType = .substrate) {
        self.networkType = networkType
    }
}

private extension ParitySignerMessageOperationFactory {
    func createRegularSigningTransactionIdentityBytes(
        for params: ParitySignerSigningIdentity.Regular,
        hasProof: Bool
    ) throws -> Data {
        guard let cryptoTypeBytes = ParitySignerCryptoType(cryptoType: params.cryptoType)?.bytes else {
            throw ParitySignerMessageOperationFactoryError.unsupportedCryptoType
        }

        let messageBytes = if hasProof {
            ParitySignerMessageType.transactionWithProof.bytes
        } else {
            ParitySignerMessageType.transaction.bytes
        }

        return cryptoTypeBytes + messageBytes + params.accountId
    }

    func createDynamicDerivationTransactionSigningIdentityBytes(
        for params: ParitySignerSigningIdentity.DynamicDerivation,
        hasProof: Bool
    ) throws -> Data {
        guard let cryptoTypeBytes = ParitySignerCryptoType(cryptoType: params.crytoType)?.bytes else {
            throw ParitySignerMessageOperationFactoryError.unsupportedCryptoType
        }

        let messageBytes = if hasProof {
            ParitySignerMessageType.ddTransactionWithProof.bytes
        } else {
            ParitySignerMessageType.ddTransaction.bytes
        }

        let derivationPathBytes = try params.derivationPath.scaleEncoded()

        return cryptoTypeBytes + messageBytes + params.rootKeyId + derivationPathBytes
    }

    func createTransactionSigningIdentityAndTypeBytes(
        for identity: ParitySignerSigningIdentity,
        hasProof: Bool
    ) throws -> Data {
        switch identity {
        case let .regular(model):
            try createRegularSigningTransactionIdentityBytes(for: model, hasProof: hasProof)
        case let .dynamicDerivation(model):
            try createDynamicDerivationTransactionSigningIdentityBytes(for: model, hasProof: hasProof)
        }
    }
}

extension ParitySignerMessageOperationFactory: ParitySignerMessageOperationFactoryProtocol {
    func createMetadataBasedTransaction(
        for extrinsicPayload: Data,
        signingIdentity: ParitySignerSigningIdentity,
        genesisHash: String
    ) -> CompoundOperationWrapper<Data> {
        let operation = ClosureOperation<Data> {
            let networkCodeBytes = self.networkType.bytes
            let signingMethodBytes = try self.createTransactionSigningIdentityAndTypeBytes(
                for: signingIdentity,
                hasProof: false
            )

            let genesisHashData = try Data(hexString: genesisHash)

            return networkCodeBytes + signingMethodBytes + extrinsicPayload + genesisHashData
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createProofBasedTransaction(
        for extrinsicPayload: Data,
        metadataProofClosure: @escaping () throws -> Data,
        signingIdentity: ParitySignerSigningIdentity,
        genesisHash: String
    ) -> CompoundOperationWrapper<Data> {
        let operation = ClosureOperation<Data> {
            let networkCodeBytes = self.networkType.bytes
            let signingMethodBytes = try self.createTransactionSigningIdentityAndTypeBytes(
                for: signingIdentity,
                hasProof: true
            )

            let genesisHashData = try Data(hexString: genesisHash)
            let metadataProof = try metadataProofClosure()

            return networkCodeBytes + signingMethodBytes + metadataProof + extrinsicPayload + genesisHashData
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createMessage(
        for payload: Data,
        accountId: AccountId,
        cryptoType: MultiassetCryptoType,
        genesisHash: String?
    ) -> CompoundOperationWrapper<Data> {
        let networkCodeBytes = networkType.bytes

        let operation = ClosureOperation<Data> {
            guard let cryptoTypeBytes = ParitySignerCryptoType(cryptoType: cryptoType)?.bytes else {
                throw ParitySignerMessageOperationFactoryError.unsupportedCryptoType
            }

            if let genesisHash {
                let messageTypeBytes = ParitySignerMessageType.concreteChainMessage.bytes

                let genesisHashData = try Data(hexString: genesisHash)

                let prefix: Data = networkCodeBytes + cryptoTypeBytes + messageTypeBytes + accountId

                return prefix + payload + genesisHashData
            } else {
                let messageTypeBytes = ParitySignerMessageType.anyChainMessage.bytes

                let prefix: Data = networkCodeBytes + cryptoTypeBytes + messageTypeBytes + accountId

                return prefix + payload
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
