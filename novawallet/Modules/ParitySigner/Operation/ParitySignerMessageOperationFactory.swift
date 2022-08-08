import Foundation
import RobinHood

enum ParitySignerNetworkType: UInt8 {
    case substrate = 83 // 0x53

    var bytes: Data {
        Data([rawValue])
    }
}

enum ParitySignerMessageType: UInt8 {
    case transaction = 2

    var bytes: Data {
        Data([rawValue])
    }
}

enum ParitySignerCryptoType: UInt8 {
    case ed25519 = 0
    case sr25519 = 1
    case ecdsa = 2

    init?(cryptoType: MultiassetCryptoType) {
        switch cryptoType {
        case .sr25519:
            self = .sr25519
        case .ed25519:
            self = .ed25519
        case .substrateEcdsa:
            self = .ecdsa
        case .ethereumEcdsa:
            return nil
        }
    }

    var bytes: Data {
        Data([rawValue])
    }
}

protocol ParitySignerMessageOperationFactoryProtocol {
    func createTransaction(
        for extrinsicPayload: Data,
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
    func createTransaction(
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

            return networkCodeBytes + cryptoTypeBytes + messageTypeBytes + accountId + extrinsicPayload + genesisHashData
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
